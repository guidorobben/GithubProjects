codeunit 50006 "UT Owner GHP"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit Assert;
        LibraryBaseURLGHP: Codeunit "Library - Base URL GHP";
        LibraryGitHubGHP: Codeunit "Library - GitHub GHP";
        DuplicateOwnerErr: Label 'Owner %1 already exists for base URL %2.', Comment = '%1 = owner name, %2 = base URL code';
        InvalidOwnerNameErr: Label 'The owner name %1 can only contain letters, digits, hyphens (-) and underscores (_).', Comment = '%1 = owner name';
        OwnerNeedsGitHubErr: Label 'Owners can only be added to a base URL with Source Type GitHub. Base URL %1 is not a GitHub base URL.', Comment = '%1 = base URL code';
        OwnerRenameErr: Label 'An owner cannot be renamed. Delete the owner and create a new one.';
        OwnerMustExistTok: Label 'The owner must exist.', Locked = true;
        OwnerMustNotExistTok: Label 'The owner must not exist.', Locked = true;
        RepositoryMustExistTok: Label 'The repository must exist.', Locked = true;
        RepositoryMustNotExistTok: Label 'The repository must not exist.', Locked = true;
        UnexpectedValueTok: Label 'Unexpected value.', Locked = true;

    [Test]
    procedure A1_OwnerOnGitHubBaseUrl()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
    begin
        // [SCENARIO A1] An owner can be created on a GitHub base URL.
        // [GIVEN] GH1
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);

        // [WHEN] An organization owner is inserted
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');

        // [THEN] It exists
        Assert.IsTrue(Owner.Get(BaseURL.Code, 'org-a'), OwnerMustExistTok);
    end;

    [Test]
    procedure A2_OwnerOnAzureBaseUrlIsRefused()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
    begin
        // [SCENARIO A2] An owner cannot belong to an Azure DevOps base URL.
        // [GIVEN] AZ
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::"Azure DevOps");

        // [WHEN] An owner validates Base URL Code AZ
        Owner.Init();
        asserterror Owner.Validate("Base URL Code", BaseURL.Code);

        // [THEN] The GitHub-only error
        Assert.ExpectedError(StrSubstNo(OwnerNeedsGitHubErr, BaseURL.Code));
    end;

    [Test]
    procedure A2a_UnvalidatedAzureBaseUrlIsRefusedOnInsert()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
    begin
        // [SCENARIO A2a] An Azure DevOps base URL assigned without validation is refused on insert.
        // [GIVEN] AZ
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::"Azure DevOps");

        // [WHEN] An owner with Base URL Code AZ is inserted with triggers
        Owner.Init();
        Owner."Base URL Code" := BaseURL.Code;
        Owner.Name := 'org-a';
        asserterror Owner.Insert(true);

        // [THEN] The GitHub-only error; no owner
        Assert.ExpectedError(StrSubstNo(OwnerNeedsGitHubErr, BaseURL.Code));
        Assert.IsFalse(Owner.Get(BaseURL.Code, 'org-a'), OwnerMustNotExistTok);
    end;

    [Test]
    procedure A3_NameIsTrimmed()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
    begin
        // [SCENARIO A3] Spaces around the owner name are removed.
        // [GIVEN] GH1
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);

        // [WHEN] Name is validated with spaces around it
        Owner.Init();
        Owner.Validate("Base URL Code", BaseURL.Code);
        Owner.Validate(Name, '  org-a  ');

        // [THEN] The name is trimmed
        Assert.AreEqual('org-a', Owner.Name, UnexpectedValueTok);
    end;

    [Test]
    procedure A3a_InvalidCharactersAreRefused()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
    begin
        // [SCENARIO A3a] A name with characters other than letters, digits, - and _ is refused.
        // [GIVEN] GH1
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);

        // [WHEN] Name is validated with ../org
        Owner.Init();
        Owner.Validate("Base URL Code", BaseURL.Code);
        asserterror Owner.Validate(Name, '../org');

        // [THEN] The invalid-name error
        Assert.ExpectedError(StrSubstNo(InvalidOwnerNameErr, '../org'));
    end;

    [Test]
    procedure A3b_UnvalidatedInvalidNameIsRefusedOnInsert()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
    begin
        // [SCENARIO A3b] An invalid name assigned without validation is refused on insert.
        // [GIVEN] GH1
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);

        // [WHEN] Name 'org a' is assigned without validation and inserted with triggers
        Owner.Init();
        Owner."Base URL Code" := BaseURL.Code;
        Owner.Name := 'org a';
        asserterror Owner.Insert(true);

        // [THEN] The invalid-name error; no owner
        Assert.ExpectedError(StrSubstNo(InvalidOwnerNameErr, 'org a'));
        Assert.IsFalse(Owner.Get(BaseURL.Code, 'org a'), OwnerMustNotExistTok);
    end;

    [Test]
    procedure A4_DuplicateNameIgnoringCaseIsRefused()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        OtherOwner: Record "Owner GHP";
    begin
        // [SCENARIO A4] The same owner name in another case is refused on the same base URL.
        // [GIVEN] ORG on GH1
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');

        // [WHEN] Another owner on GH1 validates ORG-A
        OtherOwner.Init();
        OtherOwner.Validate("Base URL Code", BaseURL.Code);
        asserterror OtherOwner.Validate(Name, 'ORG-A');

        // [THEN] The duplicate error
        Assert.ExpectedError(StrSubstNo(DuplicateOwnerErr, 'ORG-A', BaseURL.Code));
    end;

    [Test]
    procedure A4a_SameNameOnAnotherBaseUrlIsAllowed()
    var
        BaseURL: Record "Base URL GHP";
        OtherBaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        OtherOwner: Record "Owner GHP";
    begin
        // [SCENARIO A4a] The same owner name can be used on another base URL.
        // [GIVEN] ORG on GH1
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateGitHubBaseURL(OtherBaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');

        // [WHEN] An owner on GH2 gets the same name
        LibraryGitHubGHP.CreateOwner(OtherOwner, OtherBaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');

        // [THEN] No error
        Assert.IsTrue(OtherOwner.Get(OtherBaseURL.Code, 'org-a'), OwnerMustExistTok);
    end;

    [Test]
    procedure A5_RenameIsRefused()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
    begin
        // [SCENARIO A5] An owner cannot be renamed.
        // [GIVEN] ORG
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        // The asserterror below rolls back uncommitted data; the owner must survive it.
        Commit();

        // [WHEN] ORG is renamed
        asserterror Owner.Rename(BaseURL.Code, 'org-x');

        // [THEN] The rename error; ORG still exists
        Assert.ExpectedError(OwnerRenameErr);
        Assert.IsTrue(Owner.Get(BaseURL.Code, 'org-a'), OwnerMustExistTok);
    end;

    [Test]
    procedure A6_DeleteOwnerDeletesItsRepositories()
    var
        BaseURL: Record "Base URL GHP";
        OtherBaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
        OtherOwner: Record "Owner GHP";
        Repository: Record "Repository GHP";
    begin
        // [SCENARIO A6] Deleting an owner deletes its repositories, not those of other owners.
        // [GIVEN] ORG with 101 and 102; OTHER with 103
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateGitHubBaseURL(OtherBaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateOwner(OtherOwner, OtherBaseURL, Enum::"Owner Type GHP"::Organization, 'org-c');
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'repo-one');
        LibraryGitHubGHP.CreateRepository(Owner, '102', 'repo-two');
        LibraryGitHubGHP.CreateRepository(OtherOwner, '103', 'repo-three');

        // [WHEN] ORG is deleted with triggers
        Owner.Delete(true);
        Repository.SetLoadFields("Base URL Code", Id);

        // [THEN] 101 and 102 are deleted; 103 remains
        Assert.IsFalse(Repository.Get(BaseURL.Code, '101'), RepositoryMustNotExistTok);
        Assert.IsFalse(Repository.Get(BaseURL.Code, '102'), RepositoryMustNotExistTok);
        Assert.IsTrue(Repository.Get(OtherBaseURL.Code, '103'), RepositoryMustExistTok);
    end;

    [Test]
    procedure A7_NoOfRepositories()
    var
        BaseURL: Record "Base URL GHP";
        Owner: Record "Owner GHP";
    begin
        // [SCENARIO A7] The owner shows the number of stored repositories.
        // [GIVEN] ORG with 101 and 102
        LibraryGitHubGHP.CreateGitHubBaseURL(BaseURL, false);
        LibraryGitHubGHP.CreateOwner(Owner, BaseURL, Enum::"Owner Type GHP"::Organization, 'org-a');
        LibraryGitHubGHP.CreateRepository(Owner, '101', 'repo-one');
        LibraryGitHubGHP.CreateRepository(Owner, '102', 'repo-two');

        // [WHEN] No. of Repositories is calculated
        Owner.CalcFields("No. of Repositories");

        // [THEN] 2
        Assert.AreEqual(2, Owner."No. of Repositories", UnexpectedValueTok);
    end;
}
