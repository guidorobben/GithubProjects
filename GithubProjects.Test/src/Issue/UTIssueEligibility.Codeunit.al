codeunit 50016 "UT Issue Eligibility GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        LastMessage: Text;
        IssuesUpdatedWithReasonsMsg: Label 'The issues of %1 repository(ies) were updated. %2 repository(ies) were skipped: %3 with Issue Sync set to Ignore, %4 with Issues Enabled set to No (Update Repositories refreshes this), %5 of an owner with Repository Sync set to Ignore.', Comment = '%1 = number of updated repositories, %2 = number of skipped repositories, %3/%4/%5 = number skipped for each reason';
        IssueMustExistTok: Label 'The issue must exist.', Locked = true;
        UnexpectedMessageTok: Label 'Unexpected message.', Locked = true;
        UnexpectedRequestCountTok: Label 'Unexpected number of requests.', Locked = true;

    [Test]
    [HandlerFunctions('StoreMessageHandler')]
    procedure B1_IgnoredRepositoryKeepsItsIssues()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO B1] A repository with Issue Sync Ignore gets no request and keeps its issues.
        // [GIVEN] REPO-A with Issue Sync Ignore and 9001 stored
        CreateRepoA(BaseURL, Repository);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'First', Enum::"Issue State GHP"::Open);
        Repository."Issue Sync" := Repository."Issue Sync"::Ignore;
        Repository.Modify(true);
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] The issues of REPO-A are updated
        UpdateIssues(Repository);

        // [THEN] No request; 9001 still exists; 0 updated, 1 skipped because Issue Sync is Ignore
        Assert.AreEqual(0, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Issue.SetLoadFields(Id);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9001), IssueMustExistTok);
        Assert.AreEqual(StrSubstNo(IssuesUpdatedWithReasonsMsg, 0, 1, 1, 0, 0), LastMessage, UnexpectedMessageTok);
    end;

    [Test]
    [HandlerFunctions('StoreMessageHandler')]
    procedure B2_IssuesTurnedOffIsSkipped()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO B2] A repository with issues turned off in GitHub gets no request.
        // [GIVEN] REPO-A with Issues Enabled No
        CreateRepoA(BaseURL, Repository);
        Repository."Issues Enabled" := false;
        Repository.Modify(true);
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Updated
        UpdateIssues(Repository);

        // [THEN] No request; 0 updated, 1 skipped
        Assert.AreEqual(0, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Assert.AreEqual(StrSubstNo(IssuesUpdatedWithReasonsMsg, 0, 1, 0, 1, 0), LastMessage, UnexpectedMessageTok);
    end;

    [Test]
    [HandlerFunctions('StoreMessageHandler')]
    procedure B3_RepositoryOfIgnoredOwnerIsSkipped()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO B3] The repositories of an owner set to Ignore get no issue request.
        // [GIVEN] ORG with Repository Sync Ignore; REPO-A of ORG
        CreateRepoA(BaseURL, Repository);
        Owner.Get(BaseURL.Code, 'org-a');
        Owner.Validate("Repository Sync", Owner."Repository Sync"::Ignore);
        Owner.Modify(true);
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] The issues of REPO-A are updated
        UpdateIssues(Repository);

        // [THEN] No request; 0 updated, 1 skipped
        Assert.AreEqual(0, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Assert.AreEqual(StrSubstNo(IssuesUpdatedWithReasonsMsg, 0, 1, 0, 0, 1), LastMessage, UnexpectedMessageTok);
    end;

    [Test]
    [HandlerFunctions('StoreMessageHandler')]
    procedure B4_OnlyEligibleRepositoriesAreRequested()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        RepositoryB: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO B4] Of two repositories, only the eligible one is requested.
        // [GIVEN] REPO-A eligible, REPO-B with Issue Sync Ignore
        CreateRepoA(BaseURL, Repository);
        Owner.Get(BaseURL.Code, 'org-a');
        LibraryGitHubGHP.CreateRepository(Owner, '202', 'repo-b');
        RepositoryB.Get(BaseURL.Code, '202');
        RepositoryB."Issue Sync" := RepositoryB."Issue Sync"::Ignore;
        RepositoryB.Modify(true);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), '[' + LibraryGitHubGHP.I1() + ']');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] Both are updated
        Repository.Reset();
        Repository.SetRange("Base URL Code", BaseURL.Code);
        Repository.UpdateIssues();

        // [THEN] One request; 1 updated, 1 skipped because Issue Sync is Ignore
        Assert.AreEqual(1, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Assert.AreEqual(StrSubstNo(IssuesUpdatedWithReasonsMsg, 1, 1, 1, 0, 0), LastMessage, UnexpectedMessageTok);
        MockHttpHandlerGHP.AssertAllResponsesUsed();
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
    procedure StoreMessageHandler(Message: Text[1024])
    begin
        LastMessage := Message;
    end;
}
