codeunit 80004 "GitHub Client GHP"
{
    Access = Internal;

    var
        RestClient: Codeunit "Rest Client";
        BaseUrlCode: Code[20];
        ApiBaseUrl: Text;
        RateLimited: Boolean;
        RateLimitResetText: Text;
        AcceptTok: Label 'application/vnd.github+json', Locked = true;
        ApiVersionTok: Label '2022-11-28', Locked = true;
        BearerLbl: Label 'Bearer %1', Locked = true, Comment = '%1 = token';
        PerPageTok: Label 'per_page=50', Locked = true;
        RateLimitErr: Label 'GitHub rate limit reached for base URL %1. The limit resets at %2.', Comment = '%1 = base URL code, %2 = date and time';
        RequestFailedErr: Label 'The request to %1 failed with status %2 %3.', Comment = '%1 = URL, %2 = HTTP status code, %3 = reason phrase';
        TokenUserLbl: Label '%1/user', Locked = true, Comment = '%1 = base URL';
        UserAgentLbl: Label '%1/%2', Locked = true, Comment = '%1 = app name without spaces, %2 = app version';

    /// <summary>
    /// Prepares the client for one base URL: the HTTP handler, the GitHub headers and, when a token is set, the Authorization header.
    /// </summary>
    procedure Initialize(var BaseURL: Record "Base URL GHP")
    var
        AppHttpClientHandler: Codeunit "Http Client Handler GHP";
        HttpClientHandler: Interface "Http Client Handler";
        CurrentModuleInfo: ModuleInfo;
    begin
        BaseUrlCode := BaseURL.Code;
        ApiBaseUrl := BaseURL.URL;
        RateLimited := false;
        RateLimitResetText := '';

        HttpClientHandler := AppHttpClientHandler;
        OnGetHttpClientHandler(HttpClientHandler);
        RestClient := RestClient.Create(HttpClientHandler);

        NavApp.GetCurrentModuleInfo(CurrentModuleInfo);
        RestClient.SetDefaultRequestHeader('Accept', AcceptTok);
        RestClient.SetDefaultRequestHeader('X-GitHub-Api-Version', ApiVersionTok);
        RestClient.SetUserAgentHeader(StrSubstNo(UserAgentLbl, DelChr(CurrentModuleInfo.Name(), '=', ' '), CurrentModuleInfo.AppVersion()));
        if BaseURL.HasToken() then
            RestClient.SetAuthorizationHeader(SecretStrSubstNo(BearerLbl, BaseURL.GetToken()));
    end;

    /// <summary>
    /// Returns the login of the GitHub account the token belongs to.
    /// </summary>
    procedure GetTokenUserLogin(): Text
    var
        HttpResponseMessage: Codeunit "Http Response Message";
        LoginToken: JsonToken;
        Url: Text;
    begin
        Url := StrSubstNo(TokenUserLbl, ApiBaseUrl);
        HttpResponseMessage := RestClient.Get(Url);
        CheckResponse(HttpResponseMessage, Url);
        HttpResponseMessage.GetContent().AsJsonObject().Get('login', LoginToken);
        exit(LoginToken.AsValue().AsText());
    end;

    /// <summary>
    /// Requests a GitHub list with 50 items per page and follows the next links until the last page.
    /// </summary>
    procedure GetAllPages(FirstUrl: Text; var Items: JsonArray)
    var
        HttpResponseMessage: Codeunit "Http Response Message";
        PageItems: JsonArray;
        Item: JsonToken;
        Url: Text;
    begin
        Url := AddPerPage(FirstUrl);
        repeat
            HttpResponseMessage := RestClient.Get(Url);
            CheckResponse(HttpResponseMessage, Url);
            PageItems := HttpResponseMessage.GetContent().AsJsonArray();
            foreach Item in PageItems do
                Items.Add(Item);
            Url := GetNextLink(HttpResponseMessage);
        until Url = '';
    end;

    /// <summary>
    /// Returns whether the last request was refused because of a GitHub rate limit, and when the limit resets.
    /// </summary>
    procedure GetRateLimitReset(var ResetText: Text): Boolean
    begin
        ResetText := RateLimitResetText;
        exit(RateLimited);
    end;

    local procedure AddPerPage(Url: Text): Text
    begin
        if Url.Contains('?') then
            exit(Url + '&' + PerPageTok);
        exit(Url + '?' + PerPageTok);
    end;

    local procedure GetNextLink(var HttpResponseMessage: Codeunit "Http Response Message"): Text
    var
        Headers: HttpHeaders;
        LinkValues: List of [Text];
        LinkValue: Text;
        LinkPart: Text;
    begin
        Headers := HttpResponseMessage.GetHeaders();
        if not Headers.Contains('link') then
            exit('');

        Headers.GetValues('link', LinkValues);
        foreach LinkValue in LinkValues do
            foreach LinkPart in LinkValue.Split(',') do
                if LinkPart.Contains('rel="next"') then
                    exit(LinkPart.Substring(LinkPart.IndexOf('<') + 1, LinkPart.IndexOf('>') - LinkPart.IndexOf('<') - 1));
        exit('');
    end;

    local procedure CheckResponse(var HttpResponseMessage: Codeunit "Http Response Message"; Url: Text)
    var
        StatusCode: Integer;
    begin
        if HttpResponseMessage.GetIsSuccessStatusCode() then
            exit;

        StatusCode := HttpResponseMessage.GetHttpStatusCode();
        if (StatusCode in [403, 429]) and IsRateLimit(HttpResponseMessage) then begin
            RateLimited := true;
            Error(RateLimitErr, BaseUrlCode, RateLimitResetText);
        end;
        Error(RequestFailedErr, Url, StatusCode, HttpResponseMessage.GetReasonPhrase());
    end;

    local procedure IsRateLimit(var HttpResponseMessage: Codeunit "Http Response Message"): Boolean
    var
        TypeHelper: Codeunit "Type Helper";
        Headers: HttpHeaders;
        RetryAfterSeconds: Integer;
        ResetEpoch: BigInteger;
    begin
        Headers := HttpResponseMessage.GetHeaders();
        if GetHeaderValue(Headers, 'retry-after') <> '' then begin
            Evaluate(RetryAfterSeconds, GetHeaderValue(Headers, 'retry-after'));
            RateLimitResetText := Format(CurrentDateTime() + RetryAfterSeconds * 1000);
            exit(true);
        end;

        if GetHeaderValue(Headers, 'x-ratelimit-remaining') <> '0' then
            exit(false);

        if Evaluate(ResetEpoch, GetHeaderValue(Headers, 'x-ratelimit-reset')) then
            RateLimitResetText := Format(TypeHelper.EvaluateUnixTimestamp(ResetEpoch));
        exit(true);
    end;

    local procedure GetHeaderValue(var Headers: HttpHeaders; HeaderName: Text): Text
    var
        HeaderValues: List of [Text];
    begin
        if not Headers.Contains(HeaderName) then
            exit('');
        Headers.GetValues(HeaderName, HeaderValues);
        if HeaderValues.Count() = 0 then
            exit('');
        exit(HeaderValues.Get(1));
    end;

    /// <summary>
    /// Lets the test app replace the HTTP client handler with a mock, so tests never send a real request.
    /// </summary>
    [InternalEvent(false)]
    local procedure OnGetHttpClientHandler(var HttpClientHandler: Interface "Http Client Handler")
    begin
    end;
}
