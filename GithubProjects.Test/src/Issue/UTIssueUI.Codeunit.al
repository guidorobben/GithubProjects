codeunit 50021 "UT Issue UI GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        LastMessage: Text;
        IssuesUpdatedMsg: Label 'The issues of %1 repository(ies) were updated. %2 repository(ies) were skipped.', Comment = '%1 = number of updated repositories, %2 = number of skipped repositories';
        IssueMustExistTok: Label 'The issue must exist.', Locked = true;
        PageMustNotBeEditableTok: Label 'The Issues page must not be editable.', Locked = true;
        RowExpectedTok: Label 'The list must show %1.', Locked = true, Comment = '%1 = record';
        RowNotExpectedTok: Label 'The list must not show %1.', Locked = true, Comment = '%1 = record';
        UnexpectedMessageTok: Label 'Unexpected message.', Locked = true;
        UnexpectedValueTok: Label 'Unexpected value.', Locked = true;

    [Test]
    procedure P1_IssuesActionFiltersOnRepository()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        RepositoryB: Record "Repository GHP";
        Issue: Record "Issue GHP";
        RepositoriesGHP: TestPage "Repositories GHP";
        IssuesGHP: TestPage "Issues GHP";
    begin
        // [SCENARIO P1] The Issues action shows the issues of the repository with its name.
        // [GIVEN] 9001 and 9002 for REPO-A; 9003 for REPO-B
        CreateRepositories(BaseURL, Repository, RepositoryB);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'First', Enum::"Issue State GHP"::Open);
        LibraryGitHubGHP.CreateIssue(Repository, 9002, 2, 'Second', Enum::"Issue State GHP"::Closed);
        LibraryGitHubGHP.CreateIssue(RepositoryB, 9003, 3, 'Third', Enum::"Issue State GHP"::Open);

        // [WHEN] REPO-A's Issues action is chosen
        RepositoriesGHP.OpenView();
        RepositoriesGHP.GoToRecord(Repository);
        IssuesGHP.Trap();
        RepositoriesGHP.Issues.Invoke();

        // [THEN] 9001 and 9002 are shown with Repository Name repo-a; 9003 is not
        Issue.Get(BaseURL.Code, 9001);
        Assert.IsTrue(IssuesGHP.GoToRecord(Issue), StrSubstNo(RowExpectedTok, '9001'));
        Assert.AreEqual('repo-a', IssuesGHP."Repository Name".Value(), UnexpectedValueTok);
        Issue.Get(BaseURL.Code, 9002);
        Assert.IsTrue(IssuesGHP.GoToRecord(Issue), StrSubstNo(RowExpectedTok, '9002'));
        Issue.Get(BaseURL.Code, 9003);
        Assert.IsFalse(IssuesGHP.GoToRecord(Issue), StrSubstNo(RowNotExpectedTok, '9003'));
        IssuesGHP.Close();
        RepositoriesGHP.Close();
    end;

    [Test]
    procedure P2_NoOfIssuesOnRepositories()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        RepositoryB: Record "Repository GHP";
        RepositoriesGHP: TestPage "Repositories GHP";
    begin
        // [SCENARIO P2] The repository list shows the number of stored issues.
        // [GIVEN] 9001 and 9002 for REPO-A
        CreateRepositories(BaseURL, Repository, RepositoryB);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'First', Enum::"Issue State GHP"::Open);
        LibraryGitHubGHP.CreateIssue(Repository, 9002, 2, 'Second', Enum::"Issue State GHP"::Closed);

        // [WHEN] Repositories is opened on REPO-A
        RepositoriesGHP.OpenView();
        RepositoriesGHP.GoToRecord(Repository);

        // [THEN] No. of Issues = 2
        Assert.AreEqual(2, RepositoriesGHP."No. of Issues".AsInteger(), UnexpectedValueTok);
        RepositoriesGHP.Close();
    end;

    [Test]
    [HandlerFunctions('StoreMessageHandler')]
    procedure P3_UpdateIssuesAction()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        RepositoryB: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        RepositoriesGHP: TestPage "Repositories GHP";
    begin
        // [SCENARIO P3] Update Issues on the repository list updates the current repository.
        // [GIVEN] REPO-A; I1
        CreateRepositories(BaseURL, Repository, RepositoryB);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), '[' + LibraryGitHubGHP.I1() + ']');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] REPO-A is the current line and Update Issues is chosen
        RepositoriesGHP.OpenEdit();
        RepositoriesGHP.GoToRecord(Repository);
        RepositoriesGHP.UpdateIssues.Invoke();

        // [THEN] 9001 exists; 1 updated, 0 skipped
        Issue.SetLoadFields(Id);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9001), IssueMustExistTok);
        Assert.AreEqual(StrSubstNo(IssuesUpdatedMsg, 1, 0), LastMessage, UnexpectedMessageTok);
        RepositoriesGHP.Close();
    end;

    [Test]
    procedure P4_IssuesPageIsNotEditable()
    var
        IssuesGHP: TestPage "Issues GHP";
    begin
        // [SCENARIO P4] Issues cannot be changed on the list.
        // [WHEN] Issues is opened for editing
        IssuesGHP.OpenEdit();

        // [THEN] The page is not editable
        Assert.IsFalse(IssuesGHP.Editable(), PageMustNotBeEditableTok);
        IssuesGHP.Close();
    end;

    [Test]
    [HandlerFunctions('StoreMessageHandler')]
    procedure P5_UpdateRepositoriesAndIssuesAction()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        OwnersGHP: TestPage "Owners GHP";
    begin
        // [SCENARIO P5] Update Repositories and Issues on the owner list.
        // [GIVEN] ORG; the list returns REPO-A; REPO-A returns I1
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), '[' + LibraryGitHubGHP.RepositoryJson(201, 'repo-a', true) + ']');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), '[' + LibraryGitHubGHP.I1() + ']');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is the current line and Update Repositories and Issues is chosen
        OwnersGHP.OpenEdit();
        OwnersGHP.GoToRecord(Owner);
        OwnersGHP.UpdateRepositoriesAndIssues.Invoke();

        // [THEN] 9001 exists
        Issue.SetLoadFields(Id);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9001), IssueMustExistTok);
        OwnersGHP.Close();
    end;

    local procedure CreateRepositories(var BaseURL: Record "Base URL GHP"; var Repository: Record "Repository GHP"; var RepositoryB: Record "Repository GHP")
    var
        Owner: Record "Owner GHP";
    begin
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateRepository(Owner, '201', 'repo-a');
        LibraryGitHubGHP.CreateRepository(Owner, '202', 'repo-b');
        Repository.Get(BaseURL.Code, '201');
        RepositoryB.Get(BaseURL.Code, '202');
    end;

    [MessageHandler]
    procedure StoreMessageHandler(Message: Text[1024])
    begin
        LastMessage := Message;
    end;
}
