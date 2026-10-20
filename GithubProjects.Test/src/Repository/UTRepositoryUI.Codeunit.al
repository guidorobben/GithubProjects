codeunit 50012 "UT Repository UI GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        LastMessage: Text;
        UpdatedMsg: Label 'The repositories of %1 owner(s) were updated.', Comment = '%1 = number of owners';
        EditableTok: Label '%1 must be editable.', Locked = true, Comment = '%1 = field';
        NotEditableTok: Label '%1 must not be editable.', Locked = true, Comment = '%1 = field';
        RowExpectedTok: Label 'The list must show %1.', Locked = true, Comment = '%1 = record';
        RowNotExpectedTok: Label 'The list must not show %1.', Locked = true, Comment = '%1 = record';
        UnexpectedMessageTok: Label 'Unexpected message.', Locked = true;
        UnexpectedRequestCountTok: Label 'Unexpected number of requests.', Locked = true;

    [Test]
    [HandlerFunctions('StoreMessageHandler')]
    procedure P1_UpdateRepositoriesOnCurrentOwner()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        UserOwner: Record "Owner GHP";
        MockHttpHandlerGHP: Codeunit "Mock Http Handler GHP";
        OwnersGHP: TestPage "Owners GHP";
    begin
        // [SCENARIO P1] Update Repositories on the owner list updates the current owner.
        // [GIVEN] ORG and USR on GH1; a page for ORG
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(UserOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        MockHttpHandlerGHP.AddResponse(LibraryGitHubGHP.OrgReposUrl(BaseURL, 'org-a'), LibraryGitHubGHP.Page(LibraryGitHubGHP.R1()));
        BindSubscription(MockHttpHandlerGHP);

        // [WHEN] On Owners, ORG is the current line and Update Repositories is chosen
        OwnersGHP.OpenEdit();
        OwnersGHP.GoToRecord(Owner);
        OwnersGHP.UpdateRepositories.Invoke();

        // [THEN] Only ORG is requested; the message says 1 owner
        Assert.AreEqual(1, MockHttpHandlerGHP.GetRequestCount(), UnexpectedRequestCountTok);
        Assert.AreEqual(StrSubstNo(UpdatedMsg, 1), LastMessage, UnexpectedMessageTok);
        OwnersGHP.Close();
    end;

    [Test]
    procedure P2_RepositoriesActionFiltersOnOwner()
    var
        BaseURL: Record "Base URL GHP";
        OtherBaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        OtherOwner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        OwnersGHP: TestPage "Owners GHP";
        RepositoriesGHP: TestPage "Repositories GHP";
    begin
        // [SCENARIO P2] The Repositories action shows the repositories of the owner only.
        // [GIVEN] ORG with 101, OTHER with 103
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateGitHubBaseURL(OtherBaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(OtherOwner, OtherBaseURL, Enum::"Owner Type GHP"::Organization, 'org-c');
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'repo-one');
        LibraryGitHubGHP.CreateRepository(OtherOwner, '103', 'repo-three');

        // [WHEN] ORG's Repositories action is chosen
        OwnersGHP.OpenView();
        OwnersGHP.GoToRecord(Owner);
        RepositoriesGHP.Trap();
        OwnersGHP.Repositories.Invoke();

        // [THEN] 101 is shown, 103 is not
        Repository.Get(BaseURL.Code, '101');
        Assert.IsTrue(RepositoriesGHP.GoToRecord(Repository), StrSubstNo(RowExpectedTok, '101'));
        Repository.Get(OtherBaseURL.Code, '103');
        Assert.IsFalse(RepositoriesGHP.GoToRecord(Repository), StrSubstNo(RowNotExpectedTok, '103'));
        RepositoriesGHP.Close();
        OwnersGHP.Close();
    end;

    [Test]
    procedure P3_OnlyIssueSyncIsEditable()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        RepositoriesGHP: TestPage "Repositories GHP";
    begin
        // [SCENARIO P3] On the repository list only Issue Sync can be changed.
        // [GIVEN] 101 for ORG
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'repo-one');
        Repository.Get(BaseURL.Code, '101');

        // [WHEN] Repositories is opened
        RepositoriesGHP.OpenEdit();
        RepositoriesGHP.GoToRecord(Repository);

        // [THEN] Issue Sync is editable; Source Type, Name and Issues Enabled are not
        Assert.IsTrue(RepositoriesGHP."Issue Sync".Editable(), StrSubstNo(EditableTok, 'Issue Sync'));
        Assert.IsFalse(RepositoriesGHP."Source Type".Editable(), StrSubstNo(NotEditableTok, 'Source Type'));
        // Base URL Code and Owner are hidden (Visible = false), so a TestPage cannot reach them.
        Assert.IsFalse(RepositoriesGHP.Name.Editable(), StrSubstNo(NotEditableTok, 'Name'));
        Assert.IsFalse(RepositoriesGHP."Issues Enabled".Editable(), StrSubstNo(NotEditableTok, 'Issues Enabled'));
        RepositoriesGHP.Close();
    end;

    [Test]
    procedure P4_OwnersActionOnBaseUrls()
    var
        BaseURL: Record "Base URL GHP";
        OtherBaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        OtherOwner: Record "Owner GHP";
        BaseURLsGHP: TestPage "Base URLs GHP";
        OwnersGHP: TestPage "Owners GHP";
    begin
        // [SCENARIO P4] The Owners action on Base URLs shows the owners of that base URL only.
        // [GIVEN] GH1 with ORG, GH2 with OTHER
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateGitHubBaseURL(OtherBaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(OtherOwner, OtherBaseURL, Enum::"Owner Type GHP"::Organization, 'org-c');

        // [WHEN] GH1's Owners action is chosen
        BaseURLsGHP.OpenView();
        BaseURLsGHP.GoToRecord(BaseURL);
        OwnersGHP.Trap();
        BaseURLsGHP.Owners.Invoke();

        // [THEN] ORG is shown, OTHER is not
        Assert.IsTrue(OwnersGHP.GoToRecord(Owner), StrSubstNo(RowExpectedTok, 'org-a'));
        Assert.IsFalse(OwnersGHP.GoToRecord(OtherOwner), StrSubstNo(RowNotExpectedTok, 'org-c'));
        OwnersGHP.Close();
        BaseURLsGHP.Close();
    end;

    [MessageHandler]
    procedure StoreMessageHandler(Message: Text[1024])
    begin
        LastMessage := Message;
    end;
}
