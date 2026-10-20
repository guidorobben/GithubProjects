codeunit 50018 "UT Issue Delete GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        ExpectedQuestion: Text;
        DeleteIssuesQst: Label 'Do you want to delete the stored issues of %1 repository(ies)?', Comment = '%1 = number of repositories';
        IssueMustExistTok: Label 'The issue must exist.', Locked = true;
        IssueMustNotExistTok: Label 'The issue must not exist.', Locked = true;
        UnexpectedQuestionTok: Label 'Unexpected confirmation question.', Locked = true;

    [Test]
    [HandlerFunctions('ConfirmYesHandler')]
    procedure D1_DeleteIssuesAfterConfirmation()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        RepositoryB: Record "Repository GHP";
        Issue: Record "Issue GHP";
    begin
        // [SCENARIO D1] Delete Issues deletes the issues of the selected repository after confirmation.
        // [GIVEN] 9001 and 9002 for REPO-A; 9003 for REPO-B
        CreateRepositories(BaseURL, Repository, RepositoryB);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'First', Enum::"Issue State GHP"::Open);
        LibraryGitHubGHP.CreateIssue(Repository, 9002, 2, 'Second', Enum::"Issue State GHP"::Closed);
        LibraryGitHubGHP.CreateIssue(RepositoryB, 9003, 3, 'Third', Enum::"Issue State GHP"::Open);
        ExpectedQuestion := StrSubstNo(DeleteIssuesQst, 1);

        // [WHEN] Delete Issues on REPO-A, answered Yes
        Repository.SetRecFilter();
        Repository.DeleteIssuesWithConfirmation();

        // [THEN] 9001 and 9002 are deleted; 9003 is kept
        Issue.SetLoadFields(Id);
        Assert.IsFalse(Issue.Get(BaseURL.Code, 9001), IssueMustNotExistTok);
        Assert.IsFalse(Issue.Get(BaseURL.Code, 9002), IssueMustNotExistTok);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9003), IssueMustExistTok);
    end;

    [Test]
    [HandlerFunctions('ConfirmNoHandler')]
    procedure D2_DeclinedDeletesNothing()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        RepositoryB: Record "Repository GHP";
        Issue: Record "Issue GHP";
    begin
        // [SCENARIO D2] Answering No deletes nothing.
        // [GIVEN] 9001 for REPO-A
        CreateRepositories(BaseURL, Repository, RepositoryB);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'First', Enum::"Issue State GHP"::Open);
        ExpectedQuestion := StrSubstNo(DeleteIssuesQst, 1);

        // [WHEN] Delete Issues on REPO-A, answered No
        Repository.SetRecFilter();
        Repository.DeleteIssuesWithConfirmation();

        // [THEN] 9001 still exists
        Issue.SetLoadFields(Id);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9001), IssueMustExistTok);
    end;

    [Test]
    procedure D3_DeletingRepositoryDeletesIssues()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        RepositoryB: Record "Repository GHP";
        Issue: Record "Issue GHP";
    begin
        // [SCENARIO D3] Deleting a repository deletes its issues.
        // [GIVEN] 9001 for REPO-A
        CreateRepositories(BaseURL, Repository, RepositoryB);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'First', Enum::"Issue State GHP"::Open);

        // [WHEN] REPO-A is deleted with triggers
        Repository.Delete(true);

        // [THEN] 9001 is deleted
        Issue.SetLoadFields(Id);
        Assert.IsFalse(Issue.Get(BaseURL.Code, 9001), IssueMustNotExistTok);
    end;

    [Test]
    procedure D4_IgnoreKeepsIssues()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        RepositoryB: Record "Repository GHP";
        Issue: Record "Issue GHP";
    begin
        // [SCENARIO D4] Setting Issue Sync to Ignore keeps the stored issues.
        // [GIVEN] 9001 for REPO-A
        CreateRepositories(BaseURL, Repository, RepositoryB);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'First', Enum::"Issue State GHP"::Open);

        // [WHEN] Issue Sync is set to Ignore
        Repository.Validate("Issue Sync", Repository."Issue Sync"::Ignore);
        Repository.Modify(true);

        // [THEN] 9001 still exists
        Issue.SetLoadFields(Id);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9001), IssueMustExistTok);
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
