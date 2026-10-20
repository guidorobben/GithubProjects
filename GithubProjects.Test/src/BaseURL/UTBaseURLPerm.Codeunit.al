codeunit 50002 "UT Base URL Perm. GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;
    Permissions = tabledata "Base URL GHP" = ri;

    var
        Assert: Codeunit Assert;
        LibraryBaseURLGHP: Codeunit "Library - Base URL GHP";
        NoTokenPermissionErr: Label 'You do not have permission to change the token of base URL %1.', Comment = '%1 = base URL code';
        UserPermissionSetTok: Label 'Projects User GHP', Locked = true;
        AdminPermissionSetTok: Label 'Projects Admin GHP', Locked = true;
        TestPermissionSetTok: Label 'Projects Test GHP', Locked = true;
        TokenExpectedTok: Label 'The base URL must have a token.', Locked = true;
        NoTokenExpectedTok: Label 'The base URL must not have a token.', Locked = true;
        RecordMustExistTok: Label 'The base URL must be readable.', Locked = true;
        RecordMustNotExistTok: Label 'The base URL must not exist.', Locked = true;

    [Test]
    procedure C1_UserCannotSetToken()
    var
        BaseURL: Record "Base URL GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO C1] A user without write permission cannot set a token.
        // [GIVEN] GH has a token; exact permission set Projects User GHP
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.SetDummyToken(BaseURL);
        // The asserterror below rolls back uncommitted data; the base URL and its token must survive it.
        Commit();
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] A token is set
        asserterror BaseURL.SetToken(LibraryBaseURLGHP.GetDummyToken());

        // [THEN] The permission error with GH's code; GH still has a token
        Assert.ExpectedError(StrSubstNo(NoTokenPermissionErr, BaseURL."Code"));
        Assert.IsTrue(BaseURL.HasToken(), TokenExpectedTok);
        StopPermissionsMock();
    end;

    [Test]
    procedure C2_UserGetsNoDialog()
    var
        BaseURL: Record "Base URL GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO C2] A user without write permission gets the error before the dialog opens.
        // [GIVEN] GH has no token; exact permission set Projects User GHP
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] The dialog version of SetToken is called, without a page handler
        asserterror BaseURL.SetToken();

        // [THEN] The permission error; no dialog opened; GH has no token
        Assert.ExpectedError(StrSubstNo(NoTokenPermissionErr, BaseURL."Code"));
        Assert.IsFalse(BaseURL.HasToken(), NoTokenExpectedTok);
        StopPermissionsMock();
    end;

    [Test]
    procedure C3_UserCannotClearToken()
    var
        BaseURL: Record "Base URL GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO C3] A user without write permission cannot clear a token and gets no question.
        // [GIVEN] GH has a token; exact permission set Projects User GHP
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.SetDummyToken(BaseURL);
        // The asserterror below rolls back uncommitted data; the base URL and its token must survive it.
        Commit();
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] The token is cleared, without a confirmation handler
        asserterror BaseURL.ClearToken();

        // [THEN] The permission error; GH still has a token
        Assert.ExpectedError(StrSubstNo(NoTokenPermissionErr, BaseURL."Code"));
        Assert.IsTrue(BaseURL.HasToken(), TokenExpectedTok);
        StopPermissionsMock();
    end;

    [Test]
    procedure C4_UserCanReadBaseUrlAndTokenState()
    var
        BaseURL: Record "Base URL GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO C4] A user can read base URLs and whether a token is set.
        // [GIVEN] GH has a token; exact permission set Projects User GHP
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.SetDummyToken(BaseURL);
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] GH is read and HasToken is called
        // [THEN] Both succeed; HasToken is true
        Assert.IsTrue(BaseURL.Get(BaseURL."Code"), RecordMustExistTok);
        Assert.IsTrue(BaseURL.HasToken(), TokenExpectedTok);
        StopPermissionsMock();
    end;

    [Test]
    procedure C5_UserCannotInsertBaseUrl()
    var
        BaseURL: Record "Base URL GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
        BaseUrlCode: Code[20];
    begin
        // [SCENARIO C5] A user cannot create base URLs.
        // [GIVEN] Exact permission set Projects User GHP
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] A new base URL is inserted
        BaseUrlCode := 'C5';
        BaseURL.Init();
        BaseURL."Code" := BaseUrlCode;
        BaseURL.URL := LibraryBaseURLGHP.GetRandomUrl();
        asserterror BaseURL.Insert(true);

        // [THEN] An error; the record does not exist
        StopPermissionsMock();
        Assert.IsFalse(BaseURL.Get(BaseUrlCode), RecordMustNotExistTok);
    end;

    [Test]
    [HandlerFunctions('ConfirmYesHandler')]
    procedure C6_AdminCanSetAndClearToken()
    var
        BaseURL: Record "Base URL GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO C6] An admin can set and clear a token.
        // [GIVEN] GH has no token; exact permission set Projects Admin GHP
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(AdminPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] A token is set
        BaseURL.SetToken(LibraryBaseURLGHP.GetDummyToken());

        // [THEN] GH has a token
        Assert.IsTrue(BaseURL.HasToken(), TokenExpectedTok);

        // [WHEN] The token is cleared and confirmed
        BaseURL.ClearToken();

        // [THEN] GH has no token
        Assert.IsFalse(BaseURL.HasToken(), NoTokenExpectedTok);
        StopPermissionsMock();
    end;

    local procedure StartPermissionsMock()
    var
        PermissionsMock: Codeunit "Permissions Mock";
    begin
        if not PermissionsMock.IsStarted() then
            PermissionsMock.Start();
    end;

    local procedure StopPermissionsMock()
    var
        PermissionsMock: Codeunit "Permissions Mock";
    begin
        PermissionsMock.Stop();
    end;

    [ConfirmHandler]
    procedure ConfirmYesHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;
}
