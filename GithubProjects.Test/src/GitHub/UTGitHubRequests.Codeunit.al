codeunit 50008 "UT GitHub Requests GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        Any: Codeunit Any;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        RequestFailedErr: Label 'The request to %1 failed with status %2 %3.', Comment = '%1 = URL, %2 = HTTP status code, %3 = reason phrase';
        HeaderExpectedTok: Label 'Header %1 must be sent.', Locked = true, Comment = '%1 = header name';
        HeaderNotExpectedTok: Label 'Header %1 must not be sent.', Locked = true, Comment = '%1 = header name';
        RepositoryMustExistTok: Label 'The repository must exist.', Locked = true;
        UnexpectedRequestCountTok: Label 'Unexpected number of requests.', Locked = true;
        UnexpectedRequestTok: Label 'Unexpected request.', Locked = true;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure C1_OrganizationEndpointAndHeaders()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO C1] An organization is requested from /orgs/{name}/repos with the GitHub headers and the token.
        // [GIVEN] GH1 with token; ORG; one page with R1
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, true);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        UpdateOwner(Owner);

        // [THEN] One request to the organization URL with all four headers
        Assert.AreEqual(1, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        AssertHeader(MockHttpHandlerGHP, 1, 'Authorization', true);
        AssertHeader(MockHttpHandlerGHP, 1, 'Accept', true);
        AssertHeader(MockHttpHandlerGHP, 1, 'X-GitHub-Api-Version', true);
        AssertHeader(MockHttpHandlerGHP, 1, 'User-Agent', true);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure C2_UserWithoutTokenSkipsUserCall()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO C2] A user without a token is requested from /users/{name}/repos, without /user and without Authorization.
        // [GIVEN] GH1 without token; USR; one page with R1
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.UserReposUrl(BaseURL, 'user-b'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] USR is updated
        UpdateOwner(Owner);

        // [THEN] One request, no Authorization; the other headers are sent
        Assert.AreEqual(1, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        AssertHeader(MockHttpHandlerGHP, 1, 'Authorization', false);
        AssertHeader(MockHttpHandlerGHP, 1, 'Accept', true);
        AssertHeader(MockHttpHandlerGHP, 1, 'X-GitHub-Api-Version', true);
        AssertHeader(MockHttpHandlerGHP, 1, 'User-Agent', true);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure C3_TokenUserGetsPrivateRepositories()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO C3] The token's own user is requested from /user/repos, so private repositories are included.
        // [GIVEN] GH1 with token; ME; /user returns me-login (other case)
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, true);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::User, 'Me-Login');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.TokenUserUrl(BaseURL), LibraryGitHubGHP.UserJson('me-login'));
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.TokenUserReposUrl(BaseURL), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ME is updated
        UpdateOwner(Owner);

        // [THEN] /user, then /user/repos
        Assert.AreEqual(2, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Assert.AreEqual(LibraryGitHubGHP.TokenUserUrl(BaseURL), MockHttpHandlerGHP.GetRequestUrl(1), UnexpectedRequestTok);
        Assert.AreEqual(LibraryGitHubGHP.TokenUserReposUrl(BaseURL), MockHttpHandlerGHP.GetRequestUrl(2), UnexpectedRequestTok);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure C4_OtherUserWithTokenGetsPublicRepositories()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO C4] Another user than the token's user is requested from /users/{name}/repos.
        // [GIVEN] GH1 with token; USR; /user returns someone-else
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, true);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.TokenUserUrl(BaseURL), LibraryGitHubGHP.UserJson('someone-else'));
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.UserReposUrl(BaseURL, 'user-b'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] USR is updated
        UpdateOwner(Owner);

        // [THEN] /user, then /users/user-b/repos
        Assert.AreEqual(2, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Assert.AreEqual(LibraryGitHubGHP.UserReposUrl(BaseURL, 'user-b'), MockHttpHandlerGHP.GetRequestUrl(2), UnexpectedRequestTok);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure C5_TokenUserIsRequestedOncePerRun()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        OtherOwner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO C5] /user is requested once per base URL per run.
        // [GIVEN] GH1 with token; ME and USR; /user queued once
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, true);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::User, 'Me-Login');
        LibraryGitHubGHP.CreateOwner(OtherOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.TokenUserUrl(BaseURL), LibraryGitHubGHP.UserJson('me-login'));
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.TokenUserReposUrl(BaseURL), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.UserReposUrl(BaseURL, 'user-b'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R2()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Both are updated in one run
        Owner.SetRange("Base URL Code", BaseURL.Code);
        Owner.UpdateRepositories();

        // [THEN] Three requests: /user once and both lists
        Assert.AreEqual(3, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure C6_PagingFollowsNextLinks()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        Page2Url: Text;
        Page3Url: Text;
    begin
        // [SCENARIO C6] The next links are followed as given until a page has no next link.
        // [GIVEN] GH1; ORG; page 1 (R1) links to page 2 (R2), which links to page 3 (R3) without a next link
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        Page2Url := BaseURL.URL + '/x?page=2';
        Page3Url := BaseURL.URL + '/x?page=3';
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), 200, 'OK', LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()), '<' + Page2Url + '>; rel="next", <' + Page3Url + '>; rel="last"');
        MockHttpHandlerGHP.AddResponse(Page2Url, 200, 'OK', LibraryGitHubGHP.Page(LibraryGitHubGHP.R2()), '<' + Page3Url + '>; rel="next", <' + Page3Url + '>; rel="last"');
        MockHttpHandlerGHP.AddResponse(Page3Url, 200, 'OK', LibraryGitHubGHP.Page(LibraryGitHubGHP.R3()), '<' + Page2Url + '>; rel="prev"');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        UpdateOwner(Owner);

        // [THEN] Three requests in order; 101, 102 and 103 exist
        Assert.AreEqual(3, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Assert.AreEqual(Page2Url, MockHttpHandlerGHP.GetRequestUrl(2), UnexpectedRequestTok);
        Assert.AreEqual(Page3Url, MockHttpHandlerGHP.GetRequestUrl(3), UnexpectedRequestTok);
        Repository.SetLoadFields("Base URL Code", Id);
        Assert.IsTrue(Repository.Get(BaseURL.Code, '101'), RepositoryMustExistTok);
        Assert.IsTrue(Repository.Get(BaseURL.Code, '102'), RepositoryMustExistTok);
        Assert.IsTrue(Repository.Get(BaseURL.Code, '103'), RepositoryMustExistTok);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure C7_EnterpriseServerBaseUrl()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO C7] A GitHub Enterprise Server base URL with /api/v3 is used as the start of every request.
        // [GIVEN] Base URL https://ghe-<random>.invalid/api/v3; ORG
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, CopyStr('https://ghe-' + LowerCase(Any.AlphanumericText(20)) + '.invalid/api/v3', 1, 250));
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        MockHttpHandlerGHP.AddResponse(BaseURL.URL + '/orgs/org-a/repos?per_page=50', LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        UpdateOwner(Owner);

        // [THEN] The request goes to {base URL}/orgs/org-a/repos
        Assert.AreEqual(1, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
    end;

    [Test]
    procedure C8_UnsuccessfulResponseNamesStatus()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO C8] An unsuccessful response stops the owner with the URL, status code and reason phrase.
        // [GIVEN] GH1; ORG; 404 Not Found
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), 404, 'Not Found', '{"message":"Not Found"}', '');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        Owner.SetRecFilter();
        asserterror Owner.UpdateRepositories();

        // [THEN] The error names the URL, 404 and Not Found
        Assert.ExpectedError(StrSubstNo(RequestFailedErr, LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), 404, 'Not Found'));
    end;

    local procedure UpdateOwner(var Owner: Record "Owner GHP")
    begin
        Owner.SetRecFilter();
        Owner.UpdateRepositories();
    end;

    local procedure AssertHeader(var MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP"; RequestIndex: Integer; HeaderName: Text; Expected: Boolean)
    begin
        if Expected then
            Assert.IsTrue(MockHttpHandlerGHP.HadHeader(RequestIndex, HeaderName), StrSubstNo(HeaderExpectedTok, HeaderName))
        else
            Assert.IsFalse(MockHttpHandlerGHP.HadHeader(RequestIndex, HeaderName), StrSubstNo(HeaderNotExpectedTok, HeaderName));
    end;

    [MessageHandler]
    procedure UpdatedMessageHandler(Message: Text[1024])
    begin
    end;
}
