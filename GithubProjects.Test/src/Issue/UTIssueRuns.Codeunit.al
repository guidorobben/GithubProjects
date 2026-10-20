codeunit 50017 "UT Issue Runs GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        LastMessage: Text;
        RateLimitLbl: Label '%1: GitHub rate limit reached; %3 owner(s) and %4 repository(ies) skipped. The limit resets at %2.', Comment = '%1 = base URL code, %2 = date and time, %3 = number of owners, %4 = number of repositories';
        RepositoriesAndIssuesWithReasonsMsg: Label 'The repositories of %1 owner(s) and the issues of %2 repository(ies) were updated. %3 owner(s) and %4 repository(ies) were skipped. Repositories skipped: %5 with Issue Sync set to Ignore, %6 with Issues Enabled set to No.', Comment = '%1 = number of updated owners, %2 = number of updated repositories, %3 = number of skipped owners, %4 = number of skipped repositories, %5/%6 = number skipped for each reason';
        RepositoryFailedLbl: Label '%1 %2/%3: %4', Comment = '%1 = base URL code, %2 = owner, %3 = repository name, %4 = error';
        RequestFailedErr: Label 'The request to %1 failed with status %2 %3.', Comment = '%1 = URL, %2 = HTTP status code, %3 = reason phrase';
        IssueMustExistTok: Label 'The issue must exist.', Locked = true;
        RepositoryMustExistTok: Label 'The repository must exist.', Locked = true;
        UnexpectedMessageTok: Label 'Unexpected message.', Locked = true;
        UnexpectedRequestCountTok: Label 'Unexpected number of requests.', Locked = true;
        UnexpectedRequestTok: Label 'Unexpected request.', Locked = true;

    [Test]
    [HandlerFunctions('StoreMessageHandler')]
    procedure C1_RepositoriesThenIssues()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO C1] Update Repositories and Issues retrieves the repositories, then the issues of the eligible ones.
        // [GIVEN] ORG; the list returns REPO-A and REPO-B (issues turned off); REPO-A returns I1
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.RepositoryJson(201, 'repo-a', true), LibraryGitHubGHP.RepositoryJson(202, 'repo-b', false)));
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), '[' + LibraryGitHubGHP.I1() + ']');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Update Repositories and Issues on ORG
        Owner.SetRecFilter();
        Owner.UpdateRepositoriesAndIssues();

        // [THEN] The list, then REPO-A's issues; 9001 exists; 1 owner and 1 repository updated, 1 repository skipped
        Assert.AreEqual(2, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Assert.AreEqual(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), MockHttpHandlerGHP.GetRequestUrl(2), UnexpectedRequestTok);
        Issue.SetLoadFields(Id);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9001), IssueMustExistTok);
        Assert.AreEqual(StrSubstNo(RepositoriesAndIssuesWithReasonsMsg, 1, 1, 0, 1, 0, 1), LastMessage, UnexpectedMessageTok);
    end;

    [Test]
    procedure C2_FailureOfOneRepositoryDoesNotStopOthers()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO C2] One failing repository does not stop the others; the run ends with an error that names it.
        // [GIVEN] REPO-A (404) and REPO-B (I2)
        CreateTwoRepositories(BaseURL, Owner);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), 404, 'Not Found', '', '');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-b'), '[' + LibraryGitHubGHP.I2() + ']');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Both are updated
        Repository.SetRange("Base URL Code", BaseURL.Code);
        asserterror Repository.UpdateIssues();

        // [THEN] 9002 exists; the error names org-a/repo-a with 404
        Assert.ExpectedError(StrSubstNo(RepositoryFailedLbl, BaseURL.Code, 'org-a', 'repo-a', StrSubstNo(RequestFailedErr, LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), 404, 'Not Found')));
        Issue.SetLoadFields(Id);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9002), IssueMustExistTok);
    end;

    [Test]
    procedure C3_RateLimitSkipsRestOfBaseUrl()
    var
        BaseURL: Record "Base URL GHP";
        OtherBaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        OtherOwner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        TypeHelper: Codeunit "Type Helper";
        ResetEpoch: BigInteger;
    begin
        // [SCENARIO C3] A rate limit skips the other repositories of that base URL; other base URLs are still updated.
        // [GIVEN] REPO-A (rate limited) and REPO-B on GH1; REPO-C on GH2 (I1)
        ResetEpoch := 1798761600;
        CreateTwoRepositories(BaseURL, Owner);
        LibraryGitHubGHP.CreateGitHubBaseURL(OtherBaseURL, false);
        LibraryGitHubGHP.CreateOwner(OtherOwner, OtherBaseURL, Enum::"Owner Type GHP"::Organization, 'org-c');
        LibraryGitHubGHP.CreateRepository(OtherOwner, '204', 'repo-c');
        MockHttpHandlerGHP.AddRateLimitResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), 403, ResetEpoch, 0);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(OtherBaseURL, 'org-c', 'repo-c'), '[' + LibraryGitHubGHP.I1() + ']');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] All three are updated
        Repository.SetFilter("Base URL Code", '%1|%2', BaseURL.Code, OtherBaseURL.Code);
        asserterror Repository.UpdateIssues();

        // [THEN] No request for REPO-B; REPO-C updated; the rate-limit line for GH1 with 0 owners and 1 repository
        Assert.ExpectedError(StrSubstNo(RateLimitLbl, BaseURL.Code, Format(TypeHelper.EvaluateUnixTimestamp(ResetEpoch)), 0, 1));
        Assert.AreEqual(2, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Issue.SetLoadFields(Id);
        Assert.IsTrue(Issue.Get(OtherBaseURL.Code, 9001), IssueMustExistTok);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
    end;

    [Test]
    procedure C4_RateLimitOnRepositoryListStopsIssues()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        UserOwner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO C4] A rate limit on the repository list skips the other owners and all issue requests of that base URL.
        // [GIVEN] ORG (rate limited) and USR on GH1
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(UserOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        MockHttpHandlerGHP.AddRateLimitResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), 403, 1798761600, 0);
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Update Repositories and Issues on both
        Owner.SetRange("Base URL Code", BaseURL.Code);
        asserterror Owner.UpdateRepositoriesAndIssues();

        // [THEN] Only ORG's list was requested
        Assert.AreEqual(1, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
    end;

    [Test]
    procedure C5_RepositoriesKeptWhenIssuesFail()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO C5] When the issues of a repository fail, the owner's repositories are kept and the error names the repository.
        // [GIVEN] ORG returns REPO-A; REPO-A's issues fail with 404
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), '[' + LibraryGitHubGHP.RepositoryJson(201, 'repo-a', true) + ']');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), 404, 'Not Found', '', '');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Update Repositories and Issues on ORG
        Owner.SetRecFilter();
        asserterror Owner.UpdateRepositoriesAndIssues();

        // [THEN] REPO-A is stored; the error names org-a/repo-a
        Assert.ExpectedError(StrSubstNo(RepositoryFailedLbl, BaseURL.Code, 'org-a', 'repo-a', ''));
        Repository.SetLoadFields(Id);
        Assert.IsTrue(Repository.Get(BaseURL.Code, '201'), RepositoryMustExistTok);
    end;

    local procedure CreateTwoRepositories(var BaseURL: Record "Base URL GHP"; var Owner: Record "Owner GHP")
    begin
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateRepository(Owner, '201', 'repo-a');
        LibraryGitHubGHP.CreateRepository(Owner, '202', 'repo-b');
    end;

    [MessageHandler]
    procedure StoreMessageHandler(Message: Text[1024])
    begin
        LastMessage := Message;
    end;
}
