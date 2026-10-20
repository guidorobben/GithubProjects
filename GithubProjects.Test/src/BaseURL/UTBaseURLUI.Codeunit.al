codeunit 50004 "UT Base URL UI GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;
    Permissions = tabledata "Base URL GHP" = r;

    var
        Assert: Codeunit Assert;
        LibraryBaseURLGHP: Codeunit "Library - Base URL GHP";
        Any: Codeunit Any;
        TokenSetExpectedTok: Label 'Token Set must be Yes.', Locked = true;
        TokenNotSetExpectedTok: Label 'Token Set must be No.', Locked = true;
        TokenSetEditableTok: Label 'Token Set must not be editable.', Locked = true;
        UnexpectedUrlTok: Label 'The URL was not stored as expected.', Locked = true;
        DummyTokenTok: Label 'dummy-token', Locked = true;

    [Test]
    [HandlerFunctions('EnterTokenAndOkHandler')]
    procedure E1_SetTokenActionStoresToken()
    var
        BaseURL: Record "Base URL GHP";
        BaseURLsGHP: TestPage "Base URLs GHP";
    begin
        // [SCENARIO E1] Set Token stores the value entered in the dialog.
        // [GIVEN] GH has no token; the page is open on GH
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        BaseURLsGHP.OpenEdit();
        BaseURLsGHP.GoToRecord(BaseURL);

        // [WHEN] Set Token; a value is entered and OK chosen
        BaseURLsGHP.SetToken.Invoke();

        // [THEN] Token Set is Yes; GH has a token
        Assert.IsTrue(BaseURLsGHP.TokenSet.AsBoolean(), TokenSetExpectedTok);
        Assert.IsTrue(BaseURL.HasToken(), TokenSetExpectedTok);
        BaseURLsGHP.Close();
    end;

    [Test]
    [HandlerFunctions('EnterTokenAndCancelHandler')]
    procedure E2_CancelledDialogStoresNothing()
    var
        BaseURL: Record "Base URL GHP";
        BaseURLsGHP: TestPage "Base URLs GHP";
    begin
        // [SCENARIO E2] Cancelling the dialog stores nothing.
        // [GIVEN] GH has no token; the page is open on GH
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        BaseURLsGHP.OpenEdit();
        BaseURLsGHP.GoToRecord(BaseURL);

        // [WHEN] Set Token; a value is entered and Cancel chosen
        BaseURLsGHP.SetToken.Invoke();

        // [THEN] Token Set is No; GH has no token
        Assert.IsFalse(BaseURLsGHP.TokenSet.AsBoolean(), TokenNotSetExpectedTok);
        Assert.IsFalse(BaseURL.HasToken(), TokenNotSetExpectedTok);
        BaseURLsGHP.Close();
    end;

    [Test]
    [HandlerFunctions('OkWithoutTokenHandler,ConfirmYesHandler')]
    procedure E3_EmptyDialogStoresNothing()
    var
        BaseURL: Record "Base URL GHP";
        BaseURLsGHP: TestPage "Base URLs GHP";
    begin
        // [SCENARIO E3] OK without a value stores nothing.
        // [GIVEN] GH has no token; the page is open on GH
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        BaseURLsGHP.OpenEdit();
        BaseURLsGHP.GoToRecord(BaseURL);

        // [WHEN] Set Token; OK without a value, and the dialog's own question to exit without a password is answered Yes
        BaseURLsGHP.SetToken.Invoke();

        // [THEN] Token Set is No
        Assert.IsFalse(BaseURLsGHP.TokenSet.AsBoolean(), TokenNotSetExpectedTok);
        BaseURLsGHP.Close();
    end;

    [Test]
    [HandlerFunctions('ConfirmYesHandler')]
    procedure E4_ClearTokenActionDeletesToken()
    var
        BaseURL: Record "Base URL GHP";
        BaseURLsGHP: TestPage "Base URLs GHP";
    begin
        // [SCENARIO E4] Clear Token with confirmation deletes the token.
        // [GIVEN] GH has a token; the page is open on GH
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.SetDummyToken(BaseURL);
        BaseURLsGHP.OpenEdit();
        BaseURLsGHP.GoToRecord(BaseURL);

        // [WHEN] Clear Token, confirmed
        BaseURLsGHP.ClearToken.Invoke();

        // [THEN] Token Set is No
        Assert.IsFalse(BaseURLsGHP.TokenSet.AsBoolean(), TokenNotSetExpectedTok);
        BaseURLsGHP.Close();
    end;

    [Test]
    procedure E5_TokenSetIsPerRow()
    var
        GitHubBaseURL: Record "Base URL GHP";
        AzureBaseURL: Record "Base URL GHP";
        BaseURLsGHP: TestPage "Base URLs GHP";
    begin
        // [SCENARIO E5] Token Set shows the value of each row.
        // [GIVEN] GH has a token, AZ has none
        LibraryBaseURLGHP.CreateBaseURL(GitHubBaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.CreateBaseURL(AzureBaseURL, Enum::"Source Type GHP"::"Azure DevOps");
        LibraryBaseURLGHP.SetDummyToken(GitHubBaseURL);

        // [WHEN] The page is opened and moves from GH to AZ
        BaseURLsGHP.OpenView();
        BaseURLsGHP.GoToRecord(GitHubBaseURL);

        // [THEN] Token Set is Yes on GH and No on AZ
        Assert.IsTrue(BaseURLsGHP.TokenSet.AsBoolean(), TokenSetExpectedTok);
        BaseURLsGHP.GoToRecord(AzureBaseURL);
        Assert.IsFalse(BaseURLsGHP.TokenSet.AsBoolean(), TokenNotSetExpectedTok);
        BaseURLsGHP.Close();
    end;

    [Test]
    procedure E6_TokenSetIsNotEditable()
    var
        BaseURLsGHP: TestPage "Base URLs GHP";
    begin
        // [SCENARIO E6] Token Set cannot be edited.
        // [GIVEN] The page is open
        BaseURLsGHP.OpenEdit();

        // [THEN] Token Set is not editable
        Assert.IsFalse(BaseURLsGHP.TokenSet.Editable(), TokenSetEditableTok);
        BaseURLsGHP.Close();
    end;

    [Test]
    procedure E7_NewRowStoresNormalisedUrl()
    var
        BaseURL: Record "Base URL GHP";
        BaseURLsGHP: TestPage "Base URLs GHP";
        BaseUrlCode: Code[20];
        OriginalUrl: Text[250];
    begin
        // [SCENARIO E7] A row entered on the page is saved with the normalised URL.
        // [GIVEN] The page is open in a new row
        BaseUrlCode := CopyStr(Any.AlphanumericText(20), 1, 20);
        OriginalUrl := LibraryBaseURLGHP.GetRandomUrl();
        BaseURLsGHP.OpenNew();

        // [WHEN] A code and a URL with a trailing slash are entered
        BaseURLsGHP."Code".SetValue(BaseUrlCode);
        BaseURLsGHP.URL.SetValue(OriginalUrl + '/');
        BaseURLsGHP.Close();

        // [THEN] The row is saved with the URL without the slash
        BaseURL.Get(BaseUrlCode);
        Assert.AreEqual(OriginalUrl, BaseURL.URL, UnexpectedUrlTok);
    end;

    [ModalPageHandler]
    procedure EnterTokenAndOkHandler(var PasswordDialog: TestPage "Password Dialog")
    begin
        PasswordDialog.Password.SetValue(DummyTokenTok);
        PasswordDialog.OK().Invoke();
    end;

    [ModalPageHandler]
    procedure EnterTokenAndCancelHandler(var PasswordDialog: TestPage "Password Dialog")
    begin
        PasswordDialog.Password.SetValue(DummyTokenTok);
        PasswordDialog.Cancel().Invoke();
    end;

    [ModalPageHandler]
    procedure OkWithoutTokenHandler(var PasswordDialog: TestPage "Password Dialog")
    begin
        PasswordDialog.OK().Invoke();
    end;

    [ConfirmHandler]
    procedure ConfirmYesHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;
}
