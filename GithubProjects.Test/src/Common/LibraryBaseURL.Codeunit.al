codeunit 50005 "Library - Base URL GHP"
{
    Permissions = tabledata "Base URL GHP" = i;

    var
        Any: Codeunit Any;
        UrlLbl: Label 'https://%1.invalid', Locked = true, Comment = '%1 = random host name';
        DummyTokenLbl: Label 'dummy-%1', Locked = true, Comment = '%1 = random text';

    /// <summary>
    /// Creates a base URL with a random code and a random URL on the unresolvable .invalid host.
    /// </summary>
    /// <param name="BaseURL">The created base URL.</param>
    /// <param name="SourceType">The source type of the base URL.</param>
    procedure CreateBaseURL(var BaseURL: Record "Base URL GHP"; SourceType: Enum "Source Type GHP")
    begin
        BaseURL.Init();
        BaseURL.Validate("Code", CopyStr(Any.AlphanumericText(MaxStrLen(BaseURL."Code")), 1, MaxStrLen(BaseURL."Code")));
        BaseURL.Validate(URL, GetRandomUrl());
        BaseURL.Validate("Source Type", SourceType);
        BaseURL.Insert(true);
    end;

    /// <summary>
    /// Returns a random URL on the unresolvable .invalid host.
    /// </summary>
    /// <returns>The URL.</returns>
    procedure GetRandomUrl(): Text[250]
    begin
        exit(CopyStr(StrSubstNo(UrlLbl, LowerCase(Any.AlphanumericText(30))), 1, 250));
    end;

    /// <summary>
    /// Stores a random dummy token for the base URL.
    /// </summary>
    /// <param name="BaseURL">The base URL.</param>
    procedure SetDummyToken(var BaseURL: Record "Base URL GHP")
    begin
        BaseURL.SetToken(GetDummyToken());
    end;

    /// <summary>
    /// Returns a random, non-empty dummy token.
    /// </summary>
    /// <returns>The token.</returns>
    procedure GetDummyToken(): SecretText
    var
        RandomText: SecretText;
    begin
        RandomText := SecretStrSubstNo(DummyTokenLbl, Any.AlphanumericText(20));
        exit(RandomText);
    end;
}
