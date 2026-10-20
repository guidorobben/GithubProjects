codeunit 50015 "UT Issue Update GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        RepositoryFailedLbl: Label '%1 %2/%3: %4', Comment = '%1 = base URL code, %2 = owner, %3 = repository name, %4 = error';
        UnknownStateErr: Label 'GitHub returned the unknown issue state %1.', Comment = '%1 = state';
        IssueMustExistTok: Label 'The issue must exist.', Locked = true;
        IssueMustNotExistTok: Label 'The issue must not exist.', Locked = true;
        UnexpectedRequestCountTok: Label 'Unexpected number of requests.', Locked = true;
        UnexpectedValueTok: Label 'Unexpected value.', Locked = true;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure A1_IssuesAreStoredWithoutPullRequests()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO A1] Open and closed issues are stored; pull requests are skipped.
        // [GIVEN] REPO-A; the issue list returns I1, I2 and a pull request
        CreateRepoA(BaseURL, Repository);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.I1(), LibraryGitHubGHP.I2(), LibraryGitHubGHP.PullRequest()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] The issues of REPO-A are updated
        UpdateIssues(Repository);

        // [THEN] 9001 (open) and 9002 (closed) exist; the pull request does not
        Assert.AreEqual(1, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Issue.Get(BaseURL.Code, 9001);
        Assert.AreEqual(1, Issue.Number, UnexpectedValueTok);
        Assert.AreEqual('First', Issue.Description, UnexpectedValueTok);
        Assert.AreEqual(Issue.State::Open, Issue.State, UnexpectedValueTok);
        Assert.AreEqual('201', Issue."Repository Id", UnexpectedValueTok);
        Assert.AreEqual(Issue."Source Type"::GitHub, Issue."Source Type", UnexpectedValueTok);
        Assert.AreEqual(Issue.Type::Issue, Issue.Type, UnexpectedValueTok);
        Issue.Get(BaseURL.Code, 9002);
        Assert.AreEqual(Issue.State::Closed, Issue.State, UnexpectedValueTok);
        Assert.IsFalse(Issue.Get(BaseURL.Code, 9003), IssueMustNotExistTok);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure A2_IssuePagesAreFollowed()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        Page2Url: Text;
    begin
        // [SCENARIO A2] The next link of the issue list is followed.
        // [GIVEN] REPO-A; page 1 (I1) links to page 2 (I2)
        CreateRepoA(BaseURL, Repository);
        Page2Url := BaseURL.URL + '/x?page=2';
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), 200, 'OK', '[' + LibraryGitHubGHP.I1() + ']', '<' + Page2Url + '>; rel="next"');
        MockHttpHandlerGHP.AddResponse(Page2Url, '[' + LibraryGitHubGHP.I2() + ']');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Updated
        UpdateIssues(Repository);

        // [THEN] Two requests; both issues exist
        Assert.AreEqual(2, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Issue.SetLoadFields(Id);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9001), IssueMustExistTok);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9002), IssueMustExistTok);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure A3_ChangedIssueIsUpdated()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO A3] A stored issue gets the new title and state.
        // [GIVEN] 9001 stored as Old title, Open; GitHub returns it closed with title First
        CreateRepoA(BaseURL, Repository);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'Old title', Enum::"Issue State GHP"::Open);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), '[' + LibraryGitHubGHP.IssueJson(9001, 1, 'First', 'closed') + ']');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Updated
        UpdateIssues(Repository);

        // [THEN] 9001 has First, Closed
        Issue.Get(BaseURL.Code, 9001);
        Assert.AreEqual('First', Issue.Description, UnexpectedValueTok);
        Assert.AreEqual(Issue.State::Closed, Issue.State, UnexpectedValueTok);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure A4_IssueNotReturnedIsDeleted()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO A4] A stored issue that is no longer returned is deleted.
        // [GIVEN] 9001 and 9002 stored; only I1 returned
        CreateRepoA(BaseURL, Repository);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'First', Enum::"Issue State GHP"::Open);
        LibraryGitHubGHP.CreateIssue(Repository, 9002, 2, 'Second', Enum::"Issue State GHP"::Closed);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), '[' + LibraryGitHubGHP.I1() + ']');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Updated
        UpdateIssues(Repository);

        // [THEN] 9001 exists; 9002 is deleted
        Issue.SetLoadFields(Id);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9001), IssueMustExistTok);
        Assert.IsFalse(Issue.Get(BaseURL.Code, 9002), IssueMustNotExistTok);
    end;

    [Test]
    procedure A5_FailedPageChangesNothing()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        Page2Url: Text;
    begin
        // [SCENARIO A5] When a later page fails, no issue of the repository is changed.
        // [GIVEN] 9001 stored as Old title; page 1 with I2 and a next link; page 2 fails with 500
        CreateRepoA(BaseURL, Repository);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'Old title', Enum::"Issue State GHP"::Open);
        Page2Url := BaseURL.URL + '/x?page=2';
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), 200, 'OK', '[' + LibraryGitHubGHP.I2() + ']', '<' + Page2Url + '>; rel="next"');
        MockHttpHandlerGHP.AddResponse(Page2Url, 500, 'Internal Server Error', '', '');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Updated
        Repository.SetRecFilter();
        asserterror Repository.UpdateIssues();

        // [THEN] The error names org-a/repo-a; 9001 unchanged; 9002 not inserted
        Assert.ExpectedError(StrSubstNo(RepositoryFailedLbl, BaseURL.Code, 'org-a', 'repo-a', ''));
        Issue.Get(BaseURL.Code, 9001);
        Assert.AreEqual('Old title', Issue.Description, UnexpectedValueTok);
        Assert.IsFalse(Issue.Get(BaseURL.Code, 9002), IssueMustNotExistTok);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure A6_SecondUpdateGivesNoDuplicates()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO A6] Updating again with the same data gives no error and no duplicates.
        // [GIVEN] REPO-A updated once with I1 and I2
        CreateRepoA(BaseURL, Repository);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.I1(), LibraryGitHubGHP.I2()));
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.I1(), LibraryGitHubGHP.I2()));
        BindSubscription(MockHttpHandlerGHP);
        UpdateIssues(Repository);

        // [WHEN] Updated again
        UpdateIssues(Repository);

        // [THEN] Exactly two issues for REPO-A
        Issue.SetRange("Base URL Code", BaseURL.Code);
        Issue.SetRange("Repository Id", '201');
        Assert.AreEqual(2, Issue.Count(), UnexpectedValueTok);
    end;

    [Test]
    procedure A7_UnknownStateFailsRepository()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO A7] An unknown state fails the repository; nothing is stored.
        // [GIVEN] REPO-A; the list returns I1 and an issue with state unknown
        CreateRepoA(BaseURL, Repository);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.I1(), LibraryGitHubGHP.IssueJson(9002, 2, 'Second', 'unknown')));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Updated
        Repository.SetRecFilter();
        asserterror Repository.UpdateIssues();

        // [THEN] The error names the state; 9001 is not stored
        Assert.ExpectedError(StrSubstNo(UnknownStateErr, 'unknown'));
        Issue.SetLoadFields(Id);
        Assert.IsFalse(Issue.Get(BaseURL.Code, 9001), IssueMustNotExistTok);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure A8_IssueMovesToTheReturningRepository()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        RepositoryB: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO A8] An issue returned for another repository of the same base URL moves to it.
        // [GIVEN] 9001 stored for REPO-B; REPO-A returns I1
        CreateRepoA(BaseURL, Repository);
        Owner.Get(BaseURL.Code, 'org-a');
        LibraryGitHubGHP.CreateRepository(Owner, '202', 'repo-b');
        RepositoryB.Get(BaseURL.Code, '202');
        LibraryGitHubGHP.CreateIssue(RepositoryB, 9001, 1, 'First', Enum::"Issue State GHP"::Open);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), '[' + LibraryGitHubGHP.I1() + ']');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] REPO-A is updated
        UpdateIssues(Repository);

        // [THEN] 9001 belongs to REPO-A
        Issue.SetLoadFields("Repository Id");
        Issue.Get(BaseURL.Code, 9001);
        Assert.AreEqual('201', Issue."Repository Id", UnexpectedValueTok);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure A9_LongTitleIsCut()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        LongTitle: Text;
    begin
        // [SCENARIO A9] A title longer than 256 characters is cut to 256.
        // [GIVEN] REPO-A; an issue with a title of 300 characters
        CreateRepoA(BaseURL, Repository);
        LongTitle := PadStr('', 300, 'x');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), '[' + LibraryGitHubGHP.IssueJson(9001, 1, LongTitle, 'open') + ']');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Updated
        UpdateIssues(Repository);

        // [THEN] Description has the first 256 characters
        Issue.SetLoadFields(Description);
        Issue.Get(BaseURL.Code, 9001);
        Assert.AreEqual(CopyStr(LongTitle, 1, 256), Issue.Description, UnexpectedValueTok);
    end;

    local procedure CreateRepoA(var BaseURL: Record "Base URL GHP"; var Repository: Record "Repository GHP")
    var
        Owner: Record "Owner GHP";
    begin
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateRepository(Owner, '201', 'repo-a');
        Repository.Get(BaseURL.Code, '201');
    end;

    local procedure UpdateIssues(var Repository: Record "Repository GHP")
    begin
        Repository.SetRecFilter();
        Repository.UpdateIssues();
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
    end;
}
