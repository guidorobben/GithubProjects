codeunit 50013 "Mock Http Handler GHP" implements "Http Client Handler"
{
    EventSubscriberInstance = Manual;

    var
        Assert: Codeunit Assert;
        QueuedResponses: JsonArray;
        RequestedUrls: List of [Text];
        RequestHeaders: List of [Text];
        UnexpectedUrls: List of [Text];
        AllResponsesUsedTok: Label 'Not every queued response was requested: %1', Locked = true, Comment = '%1 = URLs';
        NoUnexpectedRequestTok: Label 'Requests without a queued response: %1', Locked = true, Comment = '%1 = URLs';
        UnexpectedRequestTok: Label 'The mock has no response for %1.', Locked = true, Comment = '%1 = URL';

    /// <summary>
    /// Queues a response for the next request to the URL.
    /// </summary>
    procedure AddResponse(Url: Text; StatusCode: Integer; ReasonPhrase: Text; Body: Text; LinkHeader: Text)
    var
        Headers: JsonObject;
    begin
        if LinkHeader <> '' then
            Headers.Add('link', LinkHeader);
        Queue(Url, StatusCode, ReasonPhrase, Body, Headers, false);
    end;

    /// <summary>
    /// Queues a successful response with the body and no link header.
    /// </summary>
    procedure AddResponse(Url: Text; Body: Text)
    begin
        AddResponse(Url, 200, 'OK', Body, '');
    end;

    /// <summary>
    /// Queues a GitHub rate limit response: x-ratelimit-remaining 0 with a reset time, or a retry-after header.
    /// </summary>
    procedure AddRateLimitResponse(Url: Text; StatusCode: Integer; ResetEpoch: BigInteger; RetryAfterSeconds: Integer)
    var
        Headers: JsonObject;
    begin
        if RetryAfterSeconds > 0 then
            Headers.Add('retry-after', Format(RetryAfterSeconds))
        else begin
            Headers.Add('x-ratelimit-remaining', '0');
            Headers.Add('x-ratelimit-reset', Format(ResetEpoch, 0, 9));
        end;
        Queue(Url, StatusCode, 'Forbidden', '{"message":"API rate limit exceeded"}', Headers, false);
    end;

    /// <summary>
    /// Queues a request to the URL that gets no response, as when the host cannot be reached.
    /// </summary>
    procedure AddConnectionFailure(Url: Text)
    var
        Headers: JsonObject;
    begin
        Queue(Url, 0, '', '', Headers, true);
    end;

    procedure GetRequestCount(): Integer
    begin
        exit(RequestedUrls.Count());
    end;

    procedure GetRequestUrl(Index: Integer): Text
    begin
        exit(RequestedUrls.Get(Index));
    end;

    /// <summary>
    /// Returns whether the client's default headers contained the header when the request was sent.
    /// </summary>
    procedure HadHeader(Index: Integer; HeaderName: Text): Boolean
    begin
        exit(RequestHeaders.Get(Index).Contains('|' + LowerCase(HeaderName) + '|'));
    end;

    /// <summary>
    /// Fails the test when a queued response was not requested, or a request had no queued response.
    /// </summary>
    procedure AssertAllResponsesUsed()
    var
        ResponseToken: JsonToken;
        UrlToken: JsonToken;
        UnusedUrls: Text;
    begin
        foreach ResponseToken in QueuedResponses do begin
            ResponseToken.AsObject().Get('url', UrlToken);
            UnusedUrls += UrlToken.AsValue().AsText() + ' ';
        end;
        Assert.AreEqual('', UnusedUrls, StrSubstNo(AllResponsesUsedTok, UnusedUrls));
        Assert.AreEqual(0, UnexpectedUrls.Count(), StrSubstNo(NoUnexpectedRequestTok, Format(UnexpectedUrls.Count())));
    end;

    procedure Send(CurrHttpClientInstance: HttpClient; HttpRequestMessage: Codeunit "Http Request Message"; var HttpResponseMessage: Codeunit "Http Response Message") Success: Boolean
    var
        HttpContent: Codeunit "Http Content";
        ResponseObject: JsonObject;
        PropertyToken: JsonToken;
        Url: Text;
        StatusCode: Integer;
    begin
        Url := HttpRequestMessage.GetRequestUri();
        RequestedUrls.Add(Url);
        RequestHeaders.Add(GetHeaderNames(CurrHttpClientInstance));
        if not TakeResponse(Url, ResponseObject) then begin
            UnexpectedUrls.Add(Url);
            Error(UnexpectedRequestTok, Url);
        end;

        ResponseObject.Get('connectionFailure', PropertyToken);
        if PropertyToken.AsValue().AsBoolean() then
            exit(false);

        ResponseObject.Get('status', PropertyToken);
        StatusCode := PropertyToken.AsValue().AsInteger();
        HttpResponseMessage.SetHttpStatusCode(StatusCode);
        HttpResponseMessage.SetIsSuccessStatusCode((StatusCode >= 200) and (StatusCode <= 299));
        ResponseObject.Get('reason', PropertyToken);
        HttpResponseMessage.SetReasonPhrase(PropertyToken.AsValue().AsText());
        ResponseObject.Get('body', PropertyToken);
        HttpResponseMessage.SetContent(HttpContent.Create(PropertyToken.AsValue().AsText()));
        ResponseObject.Get('headers', PropertyToken);
        HttpResponseMessage.SetHeaders(BuildHeaders(PropertyToken.AsObject()));
        exit(true);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"GitHub Client GHP", OnGetHttpClientHandler, '', false, false)]
    local procedure SupplyMockOnGetHttpClientHandler(var HttpClientHandler: Interface "Http Client Handler")
    begin
        HttpClientHandler := this;
    end;

    local procedure Queue(Url: Text; StatusCode: Integer; ReasonPhrase: Text; Body: Text; Headers: JsonObject; ConnectionFailure: Boolean)
    var
        ResponseObject: JsonObject;
    begin
        ResponseObject.Add('url', Url);
        ResponseObject.Add('status', StatusCode);
        ResponseObject.Add('reason', ReasonPhrase);
        ResponseObject.Add('body', Body);
        ResponseObject.Add('headers', Headers);
        ResponseObject.Add('connectionFailure', ConnectionFailure);
        QueuedResponses.Add(ResponseObject);
    end;

    local procedure TakeResponse(Url: Text; var ResponseObject: JsonObject): Boolean
    var
        ResponseToken: JsonToken;
        UrlToken: JsonToken;
        Index: Integer;
    begin
        for Index := 0 to QueuedResponses.Count() - 1 do begin
            QueuedResponses.Get(Index, ResponseToken);
            ResponseToken.AsObject().Get('url', UrlToken);
            if UrlToken.AsValue().AsText() = Url then begin
                ResponseObject := ResponseToken.AsObject();
                QueuedResponses.RemoveAt(Index);
                exit(true);
            end;
        end;
        exit(false);
    end;

    local procedure BuildHeaders(HeaderObject: JsonObject) Headers: HttpHeaders
    var
        NativeHttpResponseMessage: HttpResponseMessage;
        HeaderValue: JsonToken;
        HeaderName: Text;
    begin
        Headers := NativeHttpResponseMessage.Headers();
        foreach HeaderName in HeaderObject.Keys() do begin
            HeaderObject.Get(HeaderName, HeaderValue);
            Headers.TryAddWithoutValidation(HeaderName, HeaderValue.AsValue().AsText());
        end;
    end;

    local procedure GetHeaderNames(CurrHttpClientInstance: HttpClient): Text
    var
        HeaderName: Text;
        HeaderNames: Text;
    begin
        HeaderNames := '|';
        foreach HeaderName in CurrHttpClientInstance.DefaultRequestHeaders().Keys() do
            HeaderNames += LowerCase(HeaderName) + '|';
        exit(HeaderNames);
    end;
}
