codeunit 50014 "Library - GitHub GHP"
{
    Permissions =
        tabledata "Base URL GHP" = i,
        tabledata "Owner GHP" = i,
        tabledata "Repository GHP" = i;

    var
        Any: Codeunit Any;
        LibraryBaseURLGHP: Codeunit "Library - Base URL GHP";
        RepositoryJsonLbl: Label '{"id":%1,"name":"%2","has_issues":%3}', Locked = true, Comment = '%1 = id, %2 = name, %3 = true or false';
        UserJsonLbl: Label '{"login":"%1"}', Locked = true, Comment = '%1 = login';

    /// <summary>
    /// Creates a GitHub base URL on an unresolvable .invalid host, with or without a dummy token.
    /// </summary>
    procedure CreateGitHubBaseURL(var BaseURL: Record "Base URL GHP"; WithToken: Boolean)
    begin
        LibraryBaseURLGHP.CreateBaseURL(BaseURL, Enum::"Source Type GHP"::GitHub);
        if WithToken then
            LibraryBaseURLGHP.SetDummyToken(BaseURL);
    end;

    /// <summary>
    /// Creates a GitHub base URL with the given URL.
    /// </summary>
    procedure CreateGitHubBaseURL(var BaseURL: Record "Base URL GHP"; Url: Text[250])
    begin
        BaseURL.Init();
        BaseURL.Validate(Code, CopyStr(Any.AlphanumericText(MaxStrLen(BaseURL.Code)), 1, MaxStrLen(BaseURL.Code)));
        BaseURL.Validate(URL, Url);
        BaseURL.Validate("Source Type", BaseURL."Source Type"::GitHub);
        BaseURL.Insert(true);
    end;

    procedure CreateOwner(var Owner: Record "Owner GHP"; var BaseURL: Record "Base URL GHP"; OwnerType: Enum "Owner Type GHP"; OwnerName: Text[100])
    begin
        Owner.Init();
        Owner.Validate("Base URL Code", BaseURL.Code);
        Owner.Validate(Name, OwnerName);
        Owner.Validate("Owner Type", OwnerType);
        Owner.Insert(true);
    end;

    procedure CreateRepository(var Owner: Record "Owner GHP"; RepositoryId: Code[50]; RepositoryName: Text[100])
    var
        Repository: Record "Repository GHP";
    begin
        Repository.Init();
        Repository."Base URL Code" := Owner."Base URL Code";
        Repository.Id := RepositoryId;
        Repository."Source Type" := Repository."Source Type"::GitHub;
        Repository.Owner := Owner.Name;
        Repository.Name := RepositoryName;
        Repository."Issues Enabled" := true;
        Repository.Insert(true);
    end;

    procedure RepositoryJson(RepositoryId: Integer; RepositoryName: Text; IssuesEnabled: Boolean): Text
    begin
        exit(StrSubstNo(RepositoryJsonLbl, RepositoryId, RepositoryName, Format(IssuesEnabled, 0, 9)));
    end;

    procedure R1(): Text
    begin
        exit(RepositoryJson(101, 'repo-one', true));
    end;

    procedure R2(): Text
    begin
        exit(RepositoryJson(102, 'repo-two', false));
    end;

    procedure R3(): Text
    begin
        exit(RepositoryJson(103, 'repo-three', true));
    end;

    procedure Page(Repository1: Text): Text
    begin
        exit('[' + Repository1 + ']');
    end;

    procedure Page(Repository1: Text; Repository2: Text): Text
    begin
        exit('[' + Repository1 + ',' + Repository2 + ']');
    end;

    procedure UserJson(Login: Text): Text
    begin
        exit(StrSubstNo(UserJsonLbl, Login));
    end;

    procedure OrgReposUrl(var BaseURL: Record "Base URL GHP"; OwnerName: Text): Text
    begin
        exit(BaseURL.URL + '/orgs/' + OwnerName + '/repos?per_page=50');
    end;

    procedure UserReposUrl(var BaseURL: Record "Base URL GHP"; OwnerName: Text): Text
    begin
        exit(BaseURL.URL + '/users/' + OwnerName + '/repos?per_page=50');
    end;

    procedure TokenUserReposUrl(var BaseURL: Record "Base URL GHP"): Text
    begin
        exit(BaseURL.URL + '/user/repos?affiliation=owner&visibility=all&per_page=50');
    end;

    procedure TokenUserUrl(var BaseURL: Record "Base URL GHP"): Text
    begin
        exit(BaseURL.URL + '/user');
    end;
}
