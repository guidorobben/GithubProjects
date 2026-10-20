codeunit 50019 "UT GitHub Website URL GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        Any: Codeunit Any;
        GitHubWebsiteErr: Label 'The URL %1 is the GitHub website. For github.com, use https://api.github.com.', Comment = '%1 = URL';
        RecordMustNotExistTok: Label 'The base URL must not exist.', Locked = true;
        UnexpectedUrlTok: Label 'The URL was not stored as expected.', Locked = true;

    [Test]
    procedure E1_GitHubWebsiteIsRefused()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO E1] The github.com website address is refused with a hint to the API address.
        // [GIVEN] A new base URL
        BaseURL.Init();

        // [WHEN] URL is validated with https://github.com/guidorobben
        asserterror BaseURL.Validate(URL, 'https://github.com/guidorobben');

        // [THEN] The website error
        Assert.ExpectedError(StrSubstNo(GitHubWebsiteErr, 'https://github.com/guidorobben'));
    end;

    [Test]
    procedure E1a_WwwAndCapitalsAreRefused()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO E1a] www.github.com is refused as well, regardless of capitals.
        // [GIVEN] A new base URL
        BaseURL.Init();

        // [WHEN] URL is validated with https://WWW.GitHub.com
        asserterror BaseURL.Validate(URL, 'https://WWW.GitHub.com');

        // [THEN] The website error
        Assert.ExpectedError(StrSubstNo(GitHubWebsiteErr, 'https://WWW.GitHub.com'));
    end;

    [Test]
    procedure E2_UnvalidatedWebsiteIsRefusedOnInsert()
    var
        BaseURL: Record "Base URL GHP";
        BaseUrlCode: Code[20];
    begin
        // [SCENARIO E2] The website address assigned without validation is refused on insert.
        // [GIVEN] A new base URL with https://github.com assigned without validation
        BaseUrlCode := CopyStr(Any.AlphanumericText(20), 1, 20);
        BaseURL.Init();
        BaseURL.Code := BaseUrlCode;
        BaseURL.URL := 'https://github.com';

        // [WHEN] It is inserted with triggers
        asserterror BaseURL.Insert(true);

        // [THEN] The website error; no record
        Assert.ExpectedError(StrSubstNo(GitHubWebsiteErr, 'https://github.com'));
        Assert.IsFalse(BaseURL.Get(BaseUrlCode), RecordMustNotExistTok);
    end;

    [Test]
    procedure E3_OtherHostsAreAccepted()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO E3] Hosts that only contain github in their name are accepted.
        // [GIVEN] A new base URL
        BaseURL.Init();

        // [WHEN] URL is validated with a GitHub Enterprise style address and an api host
        BaseURL.Validate(URL, 'https://github.example.invalid/api/v3');
        Assert.AreEqual('https://github.example.invalid/api/v3', BaseURL.URL, UnexpectedUrlTok);
        BaseURL.Validate(URL, 'https://api.github.invalid');

        // [THEN] No error
        Assert.AreEqual('https://api.github.invalid', BaseURL.URL, UnexpectedUrlTok);
    end;
}
