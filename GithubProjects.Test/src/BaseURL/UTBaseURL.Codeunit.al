codeunit 50000 "UT Base URL GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;
    Permissions = 
        tabledata "Base URL GHP" = rim;

    var
        Assert: Codeunit Assert;
        LibraryBaseURLGHP: Codeunit "Library - Base URL GHP";
        Any: Codeunit Any;
        UrlMustBeHttpsErr: Label 'The URL %1 must start with https://.', Comment = '%1 = URL';
        DuplicateUrlErr: Label 'The URL %1 is already used by base URL %2.', Comment = '%1 = URL, %2 = base URL code';
        TestFieldTok: Label 'TestField', Locked = true;
        UnexpectedSourceTypeTok: Label 'A new base URL must get Source Type GitHub.', Locked = true;
        UnexpectedUrlTok: Label 'The URL was not stored as expected.', Locked = true;
        RecordMustNotExistTok: Label 'The base URL must not exist.', Locked = true;
        TokenExpectedTok: Label 'The base URL must have a token.', Locked = true;

    [Test]
    procedure A1_NewBaseUrlDefaultsToGitHub()
    var
        BaseURL: Record "Base URL GHP";
        BaseUrlCode: Code[20];
    begin
        // [SCENARIO A1] A new base URL is saved with Source Type GitHub.
        // [GIVEN] No base URL with a new code
        BaseUrlCode := NewCode();

        // [WHEN] A record with that code and a valid URL is inserted with triggers, Source Type not set
        BaseURL.Init();
        BaseURL."Code" := BaseUrlCode;
        BaseURL.Validate(URL, LibraryBaseURLGHP.GetRandomUrl());
        BaseURL.Insert(true);

        // [THEN] It exists with Source Type GitHub
        BaseURL.Get(BaseUrlCode);
        Assert.AreEqual(BaseURL."Source Type"::GitHub, BaseURL."Source Type", UnexpectedSourceTypeTok);
    end;

    [Test]
    procedure A2_UrlIsNormalised()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO A2] Spaces and trailing slashes are removed from the URL.
        // [GIVEN] A new record
        BaseURL.Init();

        // [WHEN] URL is validated with spaces and trailing slashes
        BaseURL.Validate(URL, '  https://api.github.com//  ');

        // [THEN] The normalised URL is stored
        Assert.AreEqual('https://api.github.com', BaseURL.URL, UnexpectedUrlTok);
    end;

    [Test]
    procedure A3_BlankUrlIsRefused()
    var
        BaseURL: Record "Base URL GHP";
        BaseUrlCode: Code[20];
    begin
        // [SCENARIO A3] A base URL cannot be inserted without a URL.
        // [GIVEN] A new record with a blank URL
        BaseUrlCode := NewCode();
        BaseURL.Init();
        BaseURL."Code" := BaseUrlCode;

        // [WHEN] It is inserted with triggers
        asserterror BaseURL.Insert(true);

        // [THEN] A TestField error on URL; the record does not exist
        Assert.ExpectedErrorCode(TestFieldTok);
        Assert.IsFalse(BaseURL.Get(BaseUrlCode), RecordMustNotExistTok);
    end;

    [Test]
    procedure A4_HttpUrlIsRefused()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO A4] A URL that does not start with https:// is refused.
        // [GIVEN] A new record
        BaseURL.Init();

        // [WHEN] URL is validated with an http URL
        asserterror BaseURL.Validate(URL, 'http://api.github.com');

        // [THEN] The https error names the URL
        Assert.ExpectedError(StrSubstNo(UrlMustBeHttpsErr, 'http://api.github.com'));
    end;

    [Test]
    procedure A4a_HttpsInUpperCaseIsAccepted()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO A4a] The https:// check ignores case.
        // [GIVEN] A new record
        BaseURL.Init();

        // [WHEN] URL is validated with HTTPS in upper case
        BaseURL.Validate(URL, 'HTTPS://Upper.invalid');

        // [THEN] No error; the value is kept
        Assert.AreEqual('HTTPS://Upper.invalid', BaseURL.URL, UnexpectedUrlTok);
    end;

    [Test]
    procedure A5_DuplicateUrlIsRefusedIgnoringCase()
    var
        ExistingBaseURL: Record "Base URL GHP";
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO A5] The same URL in another case and with a trailing slash is refused.
        // [GIVEN] GH exists with URL https://dup-<random>.invalid
        LibraryBaseURLGHP.CreateBaseURL(ExistingBaseURL, Enum::"Source Type GHP"::GitHub);

        // [WHEN] Another record validates the same URL in upper case with a trailing slash
        BaseURL.Init();
        BaseURL."Code" := NewCode();
        asserterror BaseURL.Validate(URL, CopyStr(UpperCase(ExistingBaseURL.URL) + '/', 1, MaxStrLen(BaseURL.URL)));

        // [THEN] The duplicate error names the normalised URL and GH's code
        Assert.ExpectedError(StrSubstNo(DuplicateUrlErr, UpperCase(ExistingBaseURL.URL), ExistingBaseURL."Code"));
    end;

    [Test]
    procedure A5a_OwnUrlIsNotADuplicate()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO A5a] A base URL can validate its own URL again.
        // [GIVEN] GH exists
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);

        // [WHEN] GH validates its own URL and is modified
        BaseURL.Validate(URL, BaseURL.URL);
        BaseURL.Modify(true);

        // [THEN] No error
    end;

    [Test]
    procedure A6_UnvalidatedHttpUrlIsRefusedOnInsert()
    var
        BaseURL: Record "Base URL GHP";
        BaseUrlCode: Code[20];
    begin
        // [SCENARIO A6] An http URL assigned without validation is refused on insert.
        // [GIVEN] A new record with an http URL assigned without validation
        BaseUrlCode := NewCode();
        BaseURL.Init();
        BaseURL."Code" := BaseUrlCode;
        BaseURL.URL := 'http://bypass.invalid';

        // [WHEN] It is inserted with triggers
        asserterror BaseURL.Insert(true);

        // [THEN] The https error; the record does not exist
        Assert.ExpectedError(StrSubstNo(UrlMustBeHttpsErr, 'http://bypass.invalid'));
        Assert.IsFalse(BaseURL.Get(BaseUrlCode), RecordMustNotExistTok);
    end;

    [Test]
    procedure A6a_UnvalidatedDuplicateUrlIsRefusedOnModify()
    var
        GitHubBaseURL: Record "Base URL GHP";
        AzureBaseURL: Record "Base URL GHP";
        OriginalUrl: Text[250];
    begin
        // [SCENARIO A6a] A duplicate URL assigned without validation is refused on modify.
        // [GIVEN] GH and AZ exist
        LibraryBaseURLGHP.CreateBaseURL(GitHubBaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.CreateBaseURL(AzureBaseURL, Enum::"Source Type GHP"::"Azure DevOps");
        OriginalUrl := AzureBaseURL.URL;
        // The asserterror below rolls back uncommitted data; the base URLs must survive it.
        Commit();

        // [WHEN] AZ's URL is assigned GH's URL without validation, then modified with triggers
        AzureBaseURL.URL := GitHubBaseURL.URL;
        asserterror AzureBaseURL.Modify(true);

        // [THEN] The duplicate error; AZ keeps its URL
        Assert.ExpectedError(StrSubstNo(DuplicateUrlErr, GitHubBaseURL.URL, GitHubBaseURL."Code"));
        AzureBaseURL.Get(AzureBaseURL."Code");
        Assert.AreEqual(OriginalUrl, AzureBaseURL.URL, UnexpectedUrlTok);
    end;

    [Test]
    procedure A7_RenameKeepsToken()
    var
        BaseURL: Record "Base URL GHP";
        NewBaseUrlCode: Code[20];
    begin
        // [SCENARIO A7] Renaming a base URL keeps its token.
        // [GIVEN] GH has a token
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.SetDummyToken(BaseURL);

        // [WHEN] GH is renamed
        NewBaseUrlCode := NewCode();
        BaseURL.Rename(NewBaseUrlCode);

        // [THEN] The renamed record has a token
        BaseURL.Get(NewBaseUrlCode);
        Assert.IsTrue(BaseURL.HasToken(), TokenExpectedTok);
        Assert.IsFalse(BaseURL.GetToken().IsEmpty(), TokenExpectedTok);
    end;

    [Test]
    procedure A8_UrlChangeKeepsToken()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO A8] Changing the URL of a base URL keeps its token.
        // [GIVEN] GH has a token
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.SetDummyToken(BaseURL);

        // [WHEN] GH's URL is changed
        BaseURL.Validate(URL, LibraryBaseURLGHP.GetRandomUrl());
        BaseURL.Modify(true);

        // [THEN] GH has a token
        Assert.IsTrue(BaseURL.HasToken(), TokenExpectedTok);
    end;

    local procedure NewCode(): Code[20]
    begin
        exit(CopyStr(Any.AlphanumericText(20), 1, 20));
    end;
}
