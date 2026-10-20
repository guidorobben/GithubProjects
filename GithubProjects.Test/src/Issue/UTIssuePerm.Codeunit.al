codeunit 50020 "UT Issue Perm. GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        TestPermissionSetTok: Label 'Projects Test GHP', Locked = true;
        UserPermissionSetTok: Label 'Projects User GHP', Locked = true;
        IssueMustExistTok: Label 'The issue must exist.', Locked = true;
        IssueMustNotExistTok: Label 'The issue must not exist.', Locked = true;
        UnexpectedValueTok: Label 'Unexpected value.', Locked = true;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure F1_UserCanUpdateIssues()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO F1] A user with Projects User GHP can update issues.
        // [GIVEN] REPO-A; I1; Projects User GHP
        CreateRepoA(BaseURL, Repository);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.IssuesUrl(BaseURL, 'org-a', 'repo-a'), '[' + LibraryGitHubGHP.I1() + ']');
        BindSubscription(MockHttpHandlerGHP);
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] The issues of REPO-A are updated
        Repository.SetRecFilter();
        Repository.UpdateIssues();

        // [THEN] 9001 exists
        Issue.SetLoadFields(Id);
        Assert.IsTrue(Issue.Get(BaseURL.Code, 9001), IssueMustExistTok);
        StopPermissionsMock();
    end;

    [Test]
    [HandlerFunctions('ConfirmYesHandler')]
    procedure F2_UserCanDeleteIssues()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO F2] A user with Projects User GHP can use Delete Issues.
        // [GIVEN] 9001 for REPO-A; Projects User GHP
        CreateRepoA(BaseURL, Repository);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'First', Enum::"Issue State GHP"::Open);
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] Delete Issues, answered Yes
        Repository.SetRecFilter();
        Repository.DeleteIssuesWithConfirmation();

        // [THEN] 9001 is deleted
        Issue.SetLoadFields(Id);
        Assert.IsFalse(Issue.Get(BaseURL.Code, 9001), IssueMustNotExistTok);
        StopPermissionsMock();
    end;

    [Test]
    procedure F3_UserCannotChangeIssues()
    var
        BaseURL: Record "Base URL GHP";
        Repository: Record "Repository GHP";
        Issue: Record "Issue GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO F3] A user cannot change an issue directly; only the update changes issues.
        // [GIVEN] 9001 for REPO-A; Projects User GHP
        CreateRepoA(BaseURL, Repository);
        LibraryGitHubGHP.CreateIssue(Repository, 9001, 1, 'First', Enum::"Issue State GHP"::Open);
        // The asserterror below rolls back uncommitted data; the issue must survive it.
        Commit();
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] The description is changed and modified directly
        Issue.Get(BaseURL.Code, 9001);
        Issue.Description := 'Changed';
        asserterror Issue.Modify(true);

        // [THEN] An error; the description is unchanged
        StopPermissionsMock();
        Issue.Get(BaseURL.Code, 9001);
        Assert.AreEqual('First', Issue.Description, UnexpectedValueTok);
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

    local procedure StartPermissionsMock()
    var
        PermissionsMock: Codeunit "Permissions Mock";
    begin
        if not PermissionsMock.IsStarted() then
            PermissionsMock.Start();
    end;

    local procedure StopPermissionsMock()
    var
        PermissionsMock: Codeunit "Permissions Mock";
    begin
        PermissionsMock.Stop();
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
    end;

    [ConfirmHandler]
    procedure ConfirmYesHandler(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;
}
