codeunit 50014 "Library - GitHub GHP"
{
    Permissions =
        tabledata "Base URL GHP" = i,
        tabledata "Issue GHP" = i,
        tabledata "Owner GHP" = i,
        tabledata "Repository GHP" = i;

    var
        Any: Codeunit Any;
        LibraryBaseURLGHP: Codeunit "Library - Base URL GHP";
        RepositoryJsonLbl: Label '{"id":%1,"name":"%2","has_issues":%3}', Locked = true, Comment = '%1 = id, %2 = name, %3 = true or false';
        ForkJsonLbl: Label '{"id":%1,"name":"%2","has_issues":true,"fork":true}', Locked = true, Comment = '%1 = id, %2 = name';
        UserJsonLbl: Label '{"login":"%1"}', Locked = true, Comment = '%1 = login';
        IssueJsonLbl: Label '{"id":%1,"number":%2,"title":"%3","state":"%4"}', Locked = true, Comment = '%1 = id, %2 = number, %3 = title, %4 = state';
        PullRequestJsonLbl: Label '{"id":%1,"number":%2,"title":"A pull request","state":"open","pull_request":{"url":"https://example.invalid/pulls/%2"}}', Locked = true, Comment = '%1 = id, %2 = number';
        IssuesUrlLbl: Label '%1/repos/%2/%3/issues?state=all&per_page=50', Locked = true, Comment = '%1 = base URL, %2 = owner, %3 = repository name';

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

    procedure ForkJson(RepositoryId: Integer; RepositoryName: Text): Text
    begin
        exit(StrSubstNo(ForkJsonLbl, RepositoryId, RepositoryName));
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

    procedure CreateIssue(var Repository: Record "Repository GHP"; IssueId: BigInteger; IssueNumber: Integer; Title: Text[256]; IssueState: Enum "Issue State GHP")
    var
        Issue: Record "Issue GHP";
    begin
        Issue.Init();
        Issue."Base URL Code" := Repository."Base URL Code";
        Issue.Id := IssueId;
        Issue."Source Type" := Issue."Source Type"::GitHub;
        Issue."Repository Id" := Repository.Id;
        Issue.Number := IssueNumber;
        Issue.Type := Issue.Type::Issue;
        Issue.Description := Title;
        Issue.State := IssueState;
        Issue.Insert(true);
    end;

    procedure IssueJson(IssueId: BigInteger; IssueNumber: Integer; Title: Text; IssueState: Text): Text
    begin
        exit(StrSubstNo(IssueJsonLbl, Format(IssueId, 0, 9), IssueNumber, Title, IssueState));
    end;

    procedure I1(): Text
    begin
        exit(IssueJson(9001, 1, 'First', 'open'));
    end;

    procedure I2(): Text
    begin
        exit(IssueJson(9002, 2, 'Second', 'closed'));
    end;

    procedure PullRequest(): Text
    begin
        exit(StrSubstNo(PullRequestJsonLbl, 9003, 3));
    end;

    procedure IssuesUrl(var BaseURL: Record "Base URL GHP"; OwnerName: Text; RepositoryName: Text): Text
    begin
        exit(StrSubstNo(IssuesUrlLbl, BaseURL.URL, OwnerName, RepositoryName));
    end;

    procedure Page(Item1: Text; Item2: Text; Item3: Text): Text
    begin
        exit('[' + Item1 + ',' + Item2 + ',' + Item3 + ']');
    end;
}