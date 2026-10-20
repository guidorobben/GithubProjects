codeunit 50003 "UT Env. Copy GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;
    Permissions = tabledata "Base URL GHP" = r;

    var
        Assert: Codeunit Assert;
        LibraryBaseURLGHP: Codeunit "Library - Base URL GHP";
        NoTokenExpectedTok: Label 'The base URL must not have a token.', Locked = true;
        RecordMustExistTok: Label 'The base URL must still exist.', Locked = true;

    [Test]
    procedure D1_DeleteAllTokensKeepsBaseUrls()
    var
        GitHubBaseURL: Record "Base URL GHP";
        AzureBaseURL: Record "Base URL GHP";
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO D1] After an environment copy, all tokens are deleted and the base URLs are kept.
        // [GIVEN] GH and AZ both have a token
        LibraryBaseURLGHP.CreateBaseURL(GitHubBaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.CreateBaseURL(AzureBaseURL, Enum::"Source Type GHP"::"Azure DevOps");
        LibraryBaseURLGHP.SetDummyToken(GitHubBaseURL);
        LibraryBaseURLGHP.SetDummyToken(AzureBaseURL);

        // [WHEN] DeleteAllTokens is called on an empty record, as the subscriber does
        BaseURL.DeleteAllTokens();

        // [THEN] Neither has a token; both still exist
        AssertNoTokenAndExists(GitHubBaseURL);
        AssertNoTokenAndExists(AzureBaseURL);
    end;

    [Test]
    procedure D2_DeleteAllTokensIgnoresFilters()
    var
        GitHubBaseURL: Record "Base URL GHP";
        AzureBaseURL: Record "Base URL GHP";
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO D2] Filters on the record variable do not limit DeleteAllTokens.
        // [GIVEN] GH and AZ both have a token; the record variable is filtered on GH's code
        LibraryBaseURLGHP.CreateBaseURL(GitHubBaseURL, Enum::"Source Type GHP"::GitHub);
        LibraryBaseURLGHP.CreateBaseURL(AzureBaseURL, Enum::"Source Type GHP"::"Azure DevOps");
        LibraryBaseURLGHP.SetDummyToken(GitHubBaseURL);
        LibraryBaseURLGHP.SetDummyToken(AzureBaseURL);
        BaseURL.SetRange("Code", GitHubBaseURL."Code");

        // [WHEN] DeleteAllTokens is called
        BaseURL.DeleteAllTokens();

        // [THEN] Neither has a token
        AssertNoTokenAndExists(GitHubBaseURL);
        AssertNoTokenAndExists(AzureBaseURL);
    end;

    local procedure AssertNoTokenAndExists(var BaseURL: Record "Base URL GHP")
    begin
        Assert.IsTrue(BaseURL.Get(BaseURL."Code"), RecordMustExistTok);
        Assert.IsFalse(BaseURL.HasToken(), NoTokenExpectedTok);
    end;
}
