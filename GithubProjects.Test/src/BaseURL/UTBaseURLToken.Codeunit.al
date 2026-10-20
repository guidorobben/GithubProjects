codeunit 50001 "UT Base URL Token GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;
    Permissions = tabledata "Base URL GHP" = rid;

    var
        Assert: Codeunit Assert;
        LibraryBaseURLGHP: Codeunit "Library - Base URL GHP";
        Any: Codeunit Any;
        ExpectedQuestion: Text;
        SaveBaseUrlFirstErr: Label 'Save the base URL before you set its token.';
        ClearTokenQst: Label 'Do you want to clear the token of base URL %1?', Comment = '%1 = base URL code';
        RollbackTok: Label 'Roll back the transaction.', Locked = true;
        TokenExpectedTok: Label 'The base URL must have a token.', Locked = true;
        NoTokenExpectedTok: Label 'The base URL must not have a token.', Locked = true;
        UnexpectedQuestionTok: Label 'Unexpected confirmation question.', Locked = true;
        RecordMustNotExistTok: Label 'The base URL must not exist.', Locked = true;

    [Test]
    procedure B1_SetTokenStoresToken()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO B1] Setting a token stores it for the base URL.
        // [GIVEN] GH has no token
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);

        // [WHEN] A token is set
        BaseURL.SetToken(LibraryBaseURLGHP.GetDummyToken());

        // [THEN] GH has a token
        AssertHasToken(BaseURL);
    end;

    [Test]
    procedure B2_SetTokenReplacesToken()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO B2] Setting a token again replaces it without an error.
        // [GIVEN] GH has a token
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.SetDummyToken(BaseURL);

        // [WHEN] Another token is set
        BaseURL.SetToken(LibraryBaseURLGHP.GetDummyToken());

        // [THEN] GH has a token
        AssertHasToken(BaseURL);
    end;

    [Test]
    procedure B3_TokenWriteIsRolledBack()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO B3] Storing a token is part of the transaction and is rolled back with it.
        // [GIVEN] GH without a token, committed
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        // The asserterror below rolls back uncommitted data; the base URL must survive it.
        Commit();

        // [WHEN] A token is set and then an error occurs in the same transaction
        asserterror SetTokenAndFail(BaseURL);

        // [THEN] GH has no token
        Assert.ExpectedError(RollbackTok);
        AssertHasNoToken(BaseURL);
    end;

    [Test]
    procedure B4_EmptyTokenKeepsToken()
    var
        BaseURL: Record "Base URL GHP";
        EmptyToken: SecretText;
    begin
        // [SCENARIO B4] An empty value does not change the token.
        // [GIVEN] GH has a token
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.SetDummyToken(BaseURL);

        // [WHEN] An empty token is set
        BaseURL.SetToken(EmptyToken);

        // [THEN] GH still has a token
        AssertHasToken(BaseURL);
    end;

    [Test]
    [HandlerFunctions('ConfirmYesHandler')]
    procedure B5_ClearTokenConfirmedDeletesToken()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO B5] Clearing a token after confirmation deletes it.
        // [GIVEN] GH has a token
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.SetDummyToken(BaseURL);
        ExpectedQuestion := StrSubstNo(ClearTokenQst, BaseURL."Code");

        // [WHEN] The token is cleared and the question is answered Yes
        BaseURL.ClearToken();

        // [THEN] GH has no token
        AssertHasNoToken(BaseURL);
    end;

    [Test]
    [HandlerFunctions('ConfirmNoHandler')]
    procedure B6_ClearTokenDeclinedKeepsToken()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO B6] Declining the confirmation keeps the token.
        // [GIVEN] GH has a token
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.SetDummyToken(BaseURL);
        ExpectedQuestion := StrSubstNo(ClearTokenQst, BaseURL."Code");

        // [WHEN] The token is cleared and the question is answered No
        BaseURL.ClearToken();

        // [THEN] GH has a token
        AssertHasToken(BaseURL);
    end;

    [Test]
    procedure B7_ClearTokenWithoutTokenAsksNothing()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO B7] Clearing a token that does not exist does nothing and asks nothing.
        // [GIVEN] GH has no token
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);

        // [WHEN] The token is cleared, without a confirmation handler
        BaseURL.ClearToken();

        // [THEN] No error, no question
        AssertHasNoToken(BaseURL);
    end;

    [Test]
    procedure B8_DeleteRemovesToken()
    var
        BaseURL: Record "Base URL GHP";
        BaseUrlSystemId: Guid;
        BaseUrlCode: Code[20];
        OriginalUrl: Text[250];
    begin
        // [SCENARIO B8] Deleting a base URL deletes its token.
        // [GIVEN] GH has a token
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.SetDummyToken(BaseURL);
        BaseUrlSystemId := BaseURL.SystemId;
        BaseUrlCode := BaseURL."Code";
        OriginalUrl := BaseURL.URL;

        // [WHEN] GH is deleted with triggers, and a record with the same code and SystemId is inserted again
        BaseURL.Delete(true);
        BaseURL.Init();
        BaseURL."Code" := BaseUrlCode;
        BaseURL.URL := OriginalUrl;
        BaseURL.SystemId := BaseUrlSystemId;
        BaseURL.Insert(true, true);

        // [THEN] It has no token
        AssertHasNoToken(BaseURL);
    end;

    [Test]
    procedure B9_UnsavedBaseUrlCannotGetToken()
    var
        BaseURL: Record "Base URL GHP";
        BaseUrlCode: Code[20];
    begin
        // [SCENARIO B9] A token cannot be set on a base URL that was never saved.
        // [GIVEN] An initialised record that was never inserted
        BaseUrlCode := CopyStr(Any.AlphanumericText(20), 1, 20);
        BaseURL.Init();
        BaseURL."Code" := BaseUrlCode;
        BaseURL.URL := LibraryBaseURLGHP.GetRandomUrl();

        // [WHEN] A token is set
        asserterror BaseURL.SetToken(LibraryBaseURLGHP.GetDummyToken());

        // [THEN] The save-first error; no record exists
        Assert.ExpectedError(SaveBaseUrlFirstErr);
        Assert.IsFalse(BaseURL.Get(BaseUrlCode), RecordMustNotExistTok);
    end;

    [Test]
    [HandlerFunctions('ConfirmYesHandler')]
    procedure B10_TokensAreSeparatePerBaseUrl()
    var
        GitHubBaseURL: Record "Base URL GHP";
        AzureBaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO B10] Clearing the token of one base URL keeps the token of another.
        // [GIVEN] GH and AZ both have a token
        LibraryBaseURLGHP.CreateBaseURL(GitHubBaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.CreateBaseURL(AzureBaseURL, Enum::"Source Type GHP"::"Azure DevOps");
        LibraryBaseURLGHP.SetDummyToken(GitHubBaseURL);
        LibraryBaseURLGHP.SetDummyToken(AzureBaseURL);
        ExpectedQuestion := StrSubstNo(ClearTokenQst, GitHubBaseURL."Code");

        // [WHEN] GH's token is cleared
        GitHubBaseURL.ClearToken();

        // [THEN] GH has no token; AZ has a token
        AssertHasNoToken(GitHubBaseURL);
        AssertHasToken(AzureBaseURL);
    end;

    [Test]
    procedure B11_GetTokenWithoutTokenIsEmpty()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO B11] Reading a token that was never set returns an empty value.
        // [GIVEN] AZ has never had a token
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::"Azure DevOps");

        // [WHEN] The token is read
        // [THEN] It is empty; no error
        Assert.IsTrue(BaseURL.GetToken().IsEmpty(), NoTokenExpectedTok);
    end;

    local procedure SetTokenAndFail(var BaseURL: Record "Base URL GHP")
    begin
        BaseURL.SetToken(LibraryBaseURLGHP.GetDummyToken());
        Error(RollbackTok);
    end;

    local procedure AssertHasToken(var BaseURL: Record "Base URL GHP")
    begin
        Assert.IsTrue(BaseURL.HasToken(), TokenExpectedTok);
        Assert.IsFalse(BaseURL.GetToken().IsEmpty(), TokenExpectedTok);
    end;

    local procedure AssertHasNoToken(var BaseURL: Record "Base URL GHP")
    begin
        Assert.IsFalse(BaseURL.HasToken(), NoTokenExpectedTok);
        Assert.IsTrue(BaseURL.GetToken().IsEmpty(), NoTokenExpectedTok);
    end;

    [ConfirmHandler]
    procedure ConfirmYesHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Assert.AreEqual(ExpectedQuestion, Question, UnexpectedQuestionTok);
        Reply := true;
    end;

    [ConfirmHandler]
    procedure ConfirmNoHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Assert.AreEqual(ExpectedQuestion, Question, UnexpectedQuestionTok);
        Reply := false;
    end;
}
