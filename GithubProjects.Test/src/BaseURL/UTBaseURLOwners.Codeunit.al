codeunit 50007 "UT Base URL Owners GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        Any: Codeunit Any;
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        SourceTypeInUseErr: Label 'You cannot change the Source Type of base URL %1 because it has owners.', Comment = '%1 = base URL code';
        NoTokenExpectedTok: Label 'The base URL must not have a token.', Locked = true;
        OwnerMustExistTok: Label 'The owner must exist.', Locked = true;
        OwnerMustNotExistTok: Label 'No owner of the base URL may remain.', Locked = true;
        RepositoryMustExistTok: Label 'The repository must exist.', Locked = true;
        RepositoryMustNotExistTok: Label 'No repository of the base URL may remain.', Locked = true;
        UnexpectedValueTok: Label 'Unexpected value.', Locked = true;

    [Test]
    procedure B1_DeleteBaseUrlDeletesOwnersAndRepositories()
    var
        BaseURL: Record "Base URL GHP";
        OtherBaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        UserOwner: Record "Owner GHP";
        OtherOwner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        BaseUrlSystemId: Guid;
        BaseUrlCode: Code[20];
    begin
        // [SCENARIO B1] Deleting a base URL deletes its owners, their repositories and its token.
        // [GIVEN] GH1 with token, ORG with 101, USR with 102; GH2 with OTHER and 103
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, true);
        LibraryGitHubGHP.CreateGitHubBaseURL(OtherBaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(UserOwner, BaseURL, Enum::"Owner Type GHP"::User, 'user-b');
        LibraryGitHubGHP.CreateOwner(OtherOwner, OtherBaseURL, Enum::"Owner Type GHP"::Organization, 'org-c');
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'repo-one');
        LibraryGitHubGHP.CreateRepository(UserOwner, '102', 'repo-two');
        LibraryGitHubGHP.CreateRepository(OtherOwner, '103', 'repo-three');
        BaseUrlSystemId := BaseURL.SystemId;
        BaseUrlCode := BaseURL.Code;

        // [WHEN] GH1 is deleted with triggers
        BaseURL.Delete(true);

        // [THEN] No owner or repository of GH1 remains; GH1 has no token; OTHER and 103 remain
        Owner.SetRange("Base URL Code", BaseUrlCode);
        Assert.IsTrue(Owner.IsEmpty(), OwnerMustNotExistTok);
        Repository.SetRange("Base URL Code", BaseUrlCode);
        Assert.IsTrue(Repository.IsEmpty(), RepositoryMustNotExistTok);
        Assert.IsTrue(OtherOwner.Get(OtherBaseURL.Code, 'org-c'), OwnerMustExistTok);
        Repository.Reset();
        Repository.SetLoadFields(Id);
        Assert.IsTrue(Repository.Get(OtherBaseURL.Code, '103'), RepositoryMustExistTok);
        // A record with the same SystemId shows whether the token was deleted.
        BaseURL.Init();
        BaseURL.Code := BaseUrlCode;
        BaseURL.URL := LibraryGitHubGHPUrl();
        BaseURL.SystemId := BaseUrlSystemId;
        BaseURL.Insert(false, true);
        Assert.IsFalse(BaseURL.HasToken(), NoTokenExpectedTok);
    end;

    [Test]
    procedure B2_SourceTypeChangeWithOwnersIsRefused()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
    begin
        // [SCENARIO B2] The Source Type of a base URL with owners cannot be changed.
        // [GIVEN] GH1 with ORG
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');

        // [WHEN] Source Type is validated with Azure DevOps
        asserterror BaseURL.Validate("Source Type", BaseURL."Source Type"::"Azure DevOps");

        // [THEN] The source-type error
        Assert.ExpectedError(StrSubstNo(SourceTypeInUseErr, BaseURL.Code));
    end;

    [Test]
    procedure B2a_UnvalidatedSourceTypeChangeIsRefusedOnModify()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
    begin
        // [SCENARIO B2a] A Source Type change assigned without validation is refused on modify.
        // [GIVEN] GH1 with ORG
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        // The asserterror below rolls back uncommitted data; the base URL must survive it.
        Commit();

        // [WHEN] Source Type is assigned Azure DevOps and modified with triggers
        BaseURL."Source Type" := BaseURL."Source Type"::"Azure DevOps";
        asserterror BaseURL.Modify(true);

        // [THEN] The source-type error; GH1 is still GitHub
        Assert.ExpectedError(StrSubstNo(SourceTypeInUseErr, BaseURL.Code));
        BaseURL.Get(BaseURL.Code);
        Assert.AreEqual(BaseURL."Source Type"::GitHub, BaseURL."Source Type", UnexpectedValueTok);
    end;

    [Test]
    procedure B3_SourceTypeChangeWithoutOwnersIsAllowed()
    var
        BaseURL: Record "Base URL GHP";
    begin
        // [SCENARIO B3] The Source Type of a base URL without owners can be changed.
        // [GIVEN] GH2 without owners
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);

        // [WHEN] Source Type is changed to Azure DevOps
        BaseURL.Validate("Source Type", BaseURL."Source Type"::"Azure DevOps");
        BaseURL.Modify(true);

        // [THEN] No error
        BaseURL.Get(BaseURL.Code);
        Assert.AreEqual(BaseURL."Source Type"::"Azure DevOps", BaseURL."Source Type", UnexpectedValueTok);
    end;

    [Test]
    procedure B4_RenameKeepsOwnersAndRepositories()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        Repository: Record "Repository GHP";
        NewCode: Code[20];
    begin
        // [SCENARIO B4] Renaming a base URL keeps its owners and repositories linked to it.
        // [GIVEN] GH1 with ORG and 101
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'repo-one');

        // [WHEN] GH1 is renamed
        NewCode := CopyStr(Any.AlphanumericText(20), 1, 20);
        BaseURL.Rename(NewCode);

        // [THEN] ORG and 101 have the new code
        Assert.IsTrue(Owner.Get(NewCode, 'org-a'), OwnerMustExistTok);
        Repository.SetLoadFields(Id);
        Assert.IsTrue(Repository.Get(NewCode, '101'), RepositoryMustExistTok);
    end;

    local procedure LibraryGitHubGHPUrl(): Text[250]
    var
        LibraryBaseURLGHP: Codeunit "Library - Base URL GHP";
    begin
        exit(LibraryBaseURLGHP.GetRandomUrl());
    end;
}
