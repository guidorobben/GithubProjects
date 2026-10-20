codeunit 50011 "UT Repository Perm. GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        AdminPermissionSetTok: Label 'Projects Admin GHP', Locked = true;
        TestPermissionSetTok: Label 'Projects Test GHP', Locked = true;
        UserPermissionSetTok: Label 'Projects User GHP', Locked = true;
        OwnerMustExistTok: Label 'The owner must exist.', Locked = true;
        OwnerMustNotExistTok: Label 'The owner must not exist.', Locked = true;
        RepositoryMustExistTok: Label 'The repository must exist.', Locked = true;
        RepositoryMustNotExistTok: Label 'The repository must not exist.', Locked = true;
        UnexpectedValueTok: Label 'Unexpected value.', Locked = true;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure F1_UserCanRunUpdate()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO F1] A user with Projects User GHP can update repositories.
        // [GIVEN] GH1, ORG, R1; exact permission set Projects User GHP
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] ORG is updated
        Owner.SetRecFilter();
        Owner.UpdateRepositories();

        // [THEN] 101 exists
        Repository.SetLoadFields(Id);
        Assert.IsTrue(Repository.Get(BaseURL.Code, '101'), RepositoryMustExistTok);
        StopPermissionsMock();
    end;

    [Test]
    procedure F2_UserCanChangeIssueSync()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO F2] A user with Projects User GHP can change Issue Sync.
        // [GIVEN] 101 for ORG; Projects User GHP
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'repo-one');
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] Issue Sync is set to Ignore
        Repository.Get(BaseURL.Code, '101');
        Repository.Validate("Issue Sync", Repository."Issue Sync"::Ignore);
        Repository.Modify(true);

        // [THEN] No error
        Repository.Get(BaseURL.Code, '101');
        Assert.AreEqual(Repository."Issue Sync"::Ignore, Repository."Issue Sync", UnexpectedValueTok);
        StopPermissionsMock();
    end;

    [Test]
    procedure F3_UserCannotCreateOwners()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO F3] A user with Projects User GHP cannot create owners.
        // [GIVEN] GH1; Projects User GHP
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        // The asserterror below rolls back uncommitted data; the base URL must survive it.
        Commit();
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] An owner is inserted
        Owner.Init();
        Owner."Base URL Code" := BaseURL.Code;
        Owner.Name := 'org-a';
        asserterror Owner.Insert(true);

        // [THEN] An error; no owner
        StopPermissionsMock();
        Assert.IsFalse(Owner.Get(BaseURL.Code, 'org-a'), OwnerMustNotExistTok);
    end;

    [Test]
    procedure F4_AdminCanMaintainOwners()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO F4] A user with Projects Admin GHP can create and delete owners.
        // [GIVEN] GH1; Projects Admin GHP
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(AdminPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] An owner is inserted, then deleted
        Owner.Init();
        Owner.Validate("Base URL Code", BaseURL.Code);
        Owner.Validate(Name, 'org-a');
        Owner.Insert(true);
        Assert.IsTrue(Owner.Get(BaseURL.Code, 'org-a'), OwnerMustExistTok);
        Owner.Delete(true);

        // [THEN] Both succeed
        Assert.IsFalse(Owner.Get(BaseURL.Code, 'org-a'), OwnerMustNotExistTok);
        StopPermissionsMock();
    end;

    [Test]
    procedure F5_UserCanDeleteRepository()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [SCENARIO F5] A user with Projects User GHP can delete a repository.
        // [GIVEN] 101 for ORG; Projects User GHP
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'repo-one');
        StartPermissionsMock();
        LibraryLowerPermissions.SetExactPermissionSet(UserPermissionSetTok);
        LibraryLowerPermissions.AddPermissionSet(TestPermissionSetTok);

        // [WHEN] 101 is deleted with triggers
        Repository.Get(BaseURL.Code, '101');
        Repository.Delete(true);

        // [THEN] No error; 101 no longer exists
        Repository.SetLoadFields(Id);
        Assert.IsFalse(Repository.Get(BaseURL.Code, '101'), RepositoryMustNotExistTok);
        StopPermissionsMock();
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
    procedure UpdatedMessageHandler(Message: Text[1024])
    begin
    end;
}
