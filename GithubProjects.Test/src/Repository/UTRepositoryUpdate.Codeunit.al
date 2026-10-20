codeunit 50009 "UT Repository Update GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        RepositoryMustExistTok: Label 'The repository must exist.', Locked = true;
        RepositoryMustNotExistTok: Label 'The repository must not exist.', Locked = true;
        UnexpectedValueTok: Label 'Unexpected value.', Locked = true;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure D1_NewRepositoriesAreInserted()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO D1] Returned repositories are inserted with GitHub's data, Source Type GitHub and Issue Sync Include.
        // [GIVEN] GH1; ORG without repositories; R1 and R2
        CreateOrgOwner(BaseURL, Owner);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1(), LibraryGitHubGHP.R2()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        UpdateOwner(Owner);

        // [THEN] 101 and 102 exist with the expected fields
        Repository.SetLoadFields(Name, "Issues Enabled", Owner, "Source Type", "Issue Sync");
        Repository.Get(BaseURL.Code, '101');
        Assert.AreEqual('repo-one', Repository.Name, UnexpectedValueTok);
        Assert.IsTrue(Repository."Issues Enabled", UnexpectedValueTok);
        Assert.AreEqual('org-a', Repository.Owner, UnexpectedValueTok);
        Assert.AreEqual(Repository."Source Type"::GitHub, Repository."Source Type", UnexpectedValueTok);
        Assert.AreEqual(Repository."Issue Sync"::Include, Repository."Issue Sync", UnexpectedValueTok);
        Assert.IsFalse(Repository.Fork, UnexpectedValueTok);
        Repository.SetLoadFields(Name, "Issues Enabled");
        Repository.Get(BaseURL.Code, '102');
        Assert.AreEqual('repo-two', Repository.Name, UnexpectedValueTok);
        Assert.IsFalse(Repository."Issues Enabled", UnexpectedValueTok);
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure D2_SecondUpdateGivesNoDuplicates()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO D2] Updating again with the same data gives no error and no duplicates.
        // [GIVEN] ORG updated once with R1 and R2
        CreateOrgOwner(BaseURL, Owner);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1(), LibraryGitHubGHP.R2()));
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1(), LibraryGitHubGHP.R2()));
        BindSubscription(MockHttpHandlerGHP);
        UpdateOwner(Owner);

        // [WHEN] ORG is updated again
        UpdateOwner(Owner);

        // [THEN] Exactly two repositories for ORG
        Repository.SetRange("Base URL Code", BaseURL.Code);
        Assert.AreEqual(2, Repository.Count(), UnexpectedValueTok);
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure D3_UpdateKeepsIssueSync()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO D3] A changed name is updated and the user's Issue Sync choice is kept.
        // [GIVEN] 101 stored as old-name with Issue Sync Ignore; R1
        CreateOrgOwner(BaseURL, Owner);
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'old-name');
        Repository.Get(BaseURL.Code, '101');
        Repository."Issue Sync" := Repository."Issue Sync"::Ignore;
        Repository.Modify(true);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        UpdateOwner(Owner);

        // [THEN] Name repo-one, Issue Sync Ignore
        Repository.Get(BaseURL.Code, '101');
        Assert.AreEqual('repo-one', Repository.Name, UnexpectedValueTok);
        Assert.AreEqual(Repository."Issue Sync"::Ignore, Repository."Issue Sync", UnexpectedValueTok);
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure D4_RepositoryNotReturnedIsDeleted()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO D4] A stored repository that is no longer returned is deleted.
        // [GIVEN] 101 and 102 stored; only R1 returned
        CreateOrgOwner(BaseURL, Owner);
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'repo-one');
        LibraryGitHubGHP.CreateRepository(Owner, '102', 'repo-two');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        UpdateOwner(Owner);

        // [THEN] 101 exists; 102 is deleted
        Repository.SetLoadFields(Id);
        Assert.IsTrue(Repository.Get(BaseURL.Code, '101'), RepositoryMustExistTok);
        Repository.SetLoadFields(Id);
        Assert.IsFalse(Repository.Get(BaseURL.Code, '102'), RepositoryMustNotExistTok);
    end;

    [Test]
    procedure D5_FailedPageChangesNothing()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        Page2Url: Text;
    begin
        // [SCENARIO D5] When a later page fails, nothing of the owner is inserted, changed or deleted.
        // [GIVEN] 101 (old-name) and 102 stored; page 1 with R3 and a next link; page 2 fails with 500
        CreateOrgOwner(BaseURL, Owner);
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'old-name');
        LibraryGitHubGHP.CreateRepository(Owner, '102', 'repo-two');
        Page2Url := BaseURL.URL + '/x?page=2';
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), 200, 'OK', LibraryGitHubGHP.Page(LibraryGitHubGHP.R3()), '<' + Page2Url + '>; rel="next"');
        MockHttpHandlerGHP.AddResponse(Page2Url, 500, 'Internal Server Error', '', '');
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        Owner.SetRecFilter();
        asserterror Owner.UpdateRepositories();

        // [THEN] 101 still old-name; 102 exists; 103 not inserted
        Repository.SetLoadFields(Name);
        Repository.Get(BaseURL.Code, '101');
        Assert.AreEqual('old-name', Repository.Name, UnexpectedValueTok);
        Repository.SetLoadFields(Id);
        Assert.IsTrue(Repository.Get(BaseURL.Code, '102'), RepositoryMustExistTok);
        Repository.SetLoadFields(Id);
        Assert.IsFalse(Repository.Get(BaseURL.Code, '103'), RepositoryMustNotExistTok);
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure D6_PruneOnlyTouchesTheOwner()
    var
        BaseURL: Record "Base URL GHP";
        OtherBaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        OtherOwner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO D6] Repositories of other owners are not deleted.
        // [GIVEN] 101 for ORG, 103 for OTHER; ORG returns R1 only
        CreateOrgOwner(BaseURL, Owner);
        LibraryGitHubGHP.CreateGitHubBaseURL(OtherBaseURL, false);
        LibraryGitHubGHP.CreateOwner(OtherOwner, OtherBaseURL, Enum::"Owner Type GHP"::Organization, 'org-c');
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'repo-one');
        LibraryGitHubGHP.CreateRepository(OtherOwner, '103', 'repo-three');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        UpdateOwner(Owner);

        // [THEN] 103 still exists
        Repository.SetLoadFields(Id);
        Assert.IsTrue(Repository.Get(OtherBaseURL.Code, '103'), RepositoryMustExistTok);
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure D7_TransferredRepositoryMovesToNewOwner()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        UserOwner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO D7] A repository returned for another owner of the same base URL moves to that owner and keeps Issue Sync.
        // [GIVEN] 101 stored for USR with Issue Sync Ignore; ORG returns R1
        CreateOrgOwner(BaseURL, Owner);
        LibraryGitHubGHP.CreateOwner(UserOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        LibraryGitHubGHP.CreateRepository(UserOwner, '101', 'repo-one');
        Repository.Get(BaseURL.Code, '101');
        Repository."Issue Sync" := Repository."Issue Sync"::Ignore;
        Repository.Modify(true);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        UpdateOwner(Owner);

        // [THEN] 101 belongs to org-a; Issue Sync unchanged
        Repository.Get(BaseURL.Code, '101');
        Assert.AreEqual('org-a', Repository.Owner, UnexpectedValueTok);
        Assert.AreEqual(Repository."Issue Sync"::Ignore, Repository."Issue Sync", UnexpectedValueTok);
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure H1_NewForkIsIgnored()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO H1] A new repository that is a fork is inserted with Fork Yes and Issue Sync Ignore.
        // [GIVEN] ORG returns fork 104 and R1
        CreateOrgOwner(BaseURL, Owner);
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.ForkJson(104, 'repo-fork'), LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        UpdateOwner(Owner);

        // [THEN] 104 has Fork Yes and Issue Sync Ignore; 101 has Fork No and Issue Sync Include
        Repository.Get(BaseURL.Code, '104');
        Assert.IsTrue(Repository.Fork, UnexpectedValueTok);
        Assert.AreEqual(Repository."Issue Sync"::Ignore, Repository."Issue Sync", UnexpectedValueTok);
        Repository.Get(BaseURL.Code, '101');
        Assert.IsFalse(Repository.Fork, UnexpectedValueTok);
        Assert.AreEqual(Repository."Issue Sync"::Include, Repository."Issue Sync", UnexpectedValueTok);
    end;

    [Test]
    [HandlerFunctions('UpdatedMessageHandler')]
    procedure H2_StoredForkKeepsIssueSync()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
    begin
        // [SCENARIO H2] A stored repository that GitHub returns as a fork gets Fork Yes and keeps its Issue Sync.
        // [GIVEN] 104 stored with Fork No and Issue Sync Include; ORG returns 104 as a fork
        CreateOrgOwner(BaseURL, Owner);
        LibraryGitHubGHP.CreateRepository(Owner, '104', 'repo-fork');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.ForkJson(104, 'repo-fork')));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] ORG is updated
        UpdateOwner(Owner);

        // [THEN] Fork Yes; Issue Sync Include
        Repository.Get(BaseURL.Code, '104');
        Assert.IsTrue(Repository.Fork, UnexpectedValueTok);
        Assert.AreEqual(Repository."Issue Sync"::Include, Repository."Issue Sync", UnexpectedValueTok);
    end;

    local procedure CreateOrgOwner(var BaseURL: Record "Base URL GHP"; var Owner: Record "Owner GHP")
    begin
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
    end;

    local procedure UpdateOwner(var Owner: Record "Owner GHP")
    begin
        Owner.SetRecFilter();
        Owner.UpdateRepositories();
    end;

    [MessageHandler]
    procedure UpdatedMessageHandler(Message: Text[1024])
    begin
    end;
}
