codeunit 80000 "Base URL Helper GHP"
{
    Access = Internal;
    Permissions =
        tabledata "Base URL GHP" = r,
        tabledata "Owner GHP" = rd;

    var
        ClearTokenQst: Label 'Do you want to clear the token of base URL %1?', Comment = '%1 = base URL code';
        DuplicateUrlErr: Label 'The URL %1 is already used by base URL %2.', Comment = '%1 = URL, %2 = base URL code';
        HttpsPrefixTok: Label 'https://', Locked = true;
        NoTokenPermissionErr: Label 'You do not have permission to change the token of base URL %1.', Comment = '%1 = base URL code';
        SaveBaseUrlFirstErr: Label 'Save the base URL before you set its token.';
        SourceTypeInUseErr: Label 'You cannot change the Source Type of base URL %1 because it has owners.', Comment = '%1 = base URL code';
        TokenKeyLbl: Label 'GHP-Token-%1', Locked = true, Comment = '%1 = SystemId of the base URL';
        UrlMustBeHttpsErr: Label 'The URL %1 must start with https://.', Comment = '%1 = URL';

    procedure ValidateUrl(var BaseURL: Record "Base URL GHP")
    begin
        BaseURL.URL := NormaliseUrl(BaseURL.URL);
        if BaseURL.URL = '' then
            exit;

        CheckHttps(BaseURL);
        CheckDuplicate(BaseURL);
    end;

    procedure CheckUrl(var BaseURL: Record "Base URL GHP")
    begin
        BaseURL.TestField(URL);
        CheckHttps(BaseURL);
        CheckDuplicate(BaseURL);
    end;

    procedure CheckSourceTypeChange(var BaseURL: Record "Base URL GHP"; var xBaseURL: Record "Base URL GHP")
    begin
        if BaseURL."Source Type" = xBaseURL."Source Type" then
            exit;

        if HasOwners(BaseURL) then
            Error(SourceTypeInUseErr, BaseURL.Code);
    end;

    procedure CheckSourceTypeUnchanged(var BaseURL: Record "Base URL GHP")
    var
        SavedBaseURL: Record "Base URL GHP";
    begin
        // Compares with the stored record, so a change assigned without validation is refused as well.
        SavedBaseURL.SetLoadFields("Source Type");
        if not SavedBaseURL.GetBySystemId(BaseURL.SystemId) then
            exit;

        if SavedBaseURL."Source Type" = BaseURL."Source Type" then
            exit;

        if HasOwners(BaseURL) then
            Error(SourceTypeInUseErr, BaseURL.Code);
    end;

    procedure DeleteOwners(var BaseURL: Record "Base URL GHP")
    var
        Owner: Record "Owner GHP";
    begin
        Owner.SetRange("Base URL Code", BaseURL.Code);
        Owner.DeleteAll(true);
    end;

    procedure SetToken(var BaseURL: Record "Base URL GHP")
    var
        PasswordDialogManagement: Codeunit "Password Dialog Management";
        Token: SecretText;
    begin
        CheckWritePermission(BaseURL);
        CheckSaved(BaseURL);
        Token := PasswordDialogManagement.OpenSecretPasswordDialog(true, true);
        if Token.IsEmpty() then
            exit;

        StoreToken(BaseURL, Token);
    end;

    procedure SetToken(var BaseURL: Record "Base URL GHP"; Token: SecretText)
    begin
        CheckWritePermission(BaseURL);
        CheckSaved(BaseURL);
        if Token.IsEmpty() then
            exit;

        StoreToken(BaseURL, Token);
    end;

    procedure ClearToken(var BaseURL: Record "Base URL GHP")
    var
        ConfirmManagement: Codeunit "Confirm Management";
    begin
        CheckWritePermission(BaseURL);
        if not HasToken(BaseURL) then
            exit;

        if not ConfirmManagement.GetResponseOrDefault(StrSubstNo(ClearTokenQst, BaseURL.Code), false) then
            exit;

        DeleteToken(BaseURL);
    end;

    procedure HasToken(var BaseURL: Record "Base URL GHP"): Boolean
    begin
        exit(IsolatedStorage.Contains(GetTokenKey(BaseURL), DataScope::Company));
    end;

    [NonDebuggable]
    procedure GetToken(var BaseURL: Record "Base URL GHP") Token: SecretText
    begin
        if HasToken(BaseURL) then
            IsolatedStorage.Get(GetTokenKey(BaseURL), DataScope::Company, Token);
    end;

    procedure DeleteToken(var BaseURL: Record "Base URL GHP")
    begin
        if HasToken(BaseURL) then
            IsolatedStorage.Delete(GetTokenKey(BaseURL), DataScope::Company);
    end;

    procedure DeleteAllTokens()
    var
        BaseURL: Record "Base URL GHP";
    begin
        BaseURL.SetLoadFields(Code);
        if BaseURL.FindSet() then
            repeat
                DeleteToken(BaseURL);
            until BaseURL.Next() = 0;
    end;

    local procedure NormaliseUrl(Url: Text[250]): Text[250]
    var
        NormalisedUrl: Text;
    begin
        NormalisedUrl := DelChr(Url, '<>', ' ');
        while NormalisedUrl.EndsWith('/') do
            NormalisedUrl := CopyStr(NormalisedUrl, 1, StrLen(NormalisedUrl) - 1);
        exit(CopyStr(NormalisedUrl, 1, MaxStrLen(Url)));
    end;

    local procedure CheckHttps(var BaseURL: Record "Base URL GHP")
    begin
        if not LowerCase(BaseURL.URL).StartsWith(HttpsPrefixTok) then
            Error(UrlMustBeHttpsErr, BaseURL.URL);
    end;

    local procedure CheckDuplicate(var BaseURL: Record "Base URL GHP")
    var
        OtherBaseURL: Record "Base URL GHP";
        LowerCaseUrl: Text;
    begin
        // A loop instead of a filter: a URL can contain filter characters such as & and |, and the comparison must ignore case.
        LowerCaseUrl := LowerCase(BaseURL.URL);
        OtherBaseURL.SetFilter(Code, '<>%1', BaseURL.Code);
        OtherBaseURL.SetLoadFields(Code, URL);
        if OtherBaseURL.FindSet() then
            repeat
                if LowerCase(OtherBaseURL.URL) = LowerCaseUrl then
                    Error(DuplicateUrlErr, BaseURL.URL, OtherBaseURL.Code);
            until OtherBaseURL.Next() = 0;
    end;

    local procedure CheckWritePermission(var BaseURL: Record "Base URL GHP")
    begin
        if not BaseURL.WritePermission() then
            Error(NoTokenPermissionErr, BaseURL.Code);
    end;

    local procedure CheckSaved(var BaseURL: Record "Base URL GHP")
    var
        SavedBaseURL: Record "Base URL GHP";
    begin
        if IsNullGuid(BaseURL.SystemId) then
            Error(SaveBaseUrlFirstErr);

        SavedBaseURL.SetLoadFields(Code);
        if not SavedBaseURL.GetBySystemId(BaseURL.SystemId) then
            Error(SaveBaseUrlFirstErr);
    end;

    local procedure HasOwners(var BaseURL: Record "Base URL GHP"): Boolean
    var
        Owner: Record "Owner GHP";
    begin
        Owner.SetRange("Base URL Code", BaseURL.Code);
        exit(not Owner.IsEmpty());
    end;

    local procedure StoreToken(var BaseURL: Record "Base URL GHP"; Token: SecretText)
    begin
        IsolatedStorage.Set(GetTokenKey(BaseURL), Token, DataScope::Company);
    end;

    local procedure GetTokenKey(var BaseURL: Record "Base URL GHP"): Text
    begin
        exit(StrSubstNo(TokenKeyLbl, Format(BaseURL.SystemId, 0, 4)));
    end;
}
