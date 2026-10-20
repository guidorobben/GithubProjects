table 80000 "Base URL GHP"
{
    Caption = 'Base URL';
    DataClassification = CustomerContent;
    DrillDownPageId = "Base URLs GHP";
    LookupPageId = "Base URLs GHP";

    fields
    {
        field(1; Code; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
            ToolTip = 'Specifies the code that identifies the base URL.';
        }
        field(2; URL; Text[250])
        {
            Caption = 'URL';
            ExtendedDatatype = URL;
            ToolTip = 'Specifies the base URL of the API, for example https://api.github.com or https://dev.azure.com/{organization}. The URL must start with https://.';

            trigger OnValidate()
            begin
                BaseURLHelper.ValidateUrl(Rec);
            end;
        }
        field(3; "Source Type"; Enum "Source Type GHP")
        {
            Caption = 'Source Type';
            ToolTip = 'Specifies whether the base URL belongs to GitHub or to Azure DevOps. It decides which API is called and how the token is sent.';
        }
    }

    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
        key(UniqueURL; URL)
        {
            Unique = true;
        }
    }

    trigger OnInsert()
    begin
        BaseURLHelper.CheckUrl(Rec);
    end;

    trigger OnModify()
    begin
        BaseURLHelper.CheckUrl(Rec);
    end;

    trigger OnDelete()
    begin
        BaseURLHelper.DeleteToken(Rec);
    end;

    var
        BaseURLHelper: Codeunit "Base URL Helper GHP";

    /// <summary>
    /// Opens a masked dialog and stores the entered value as the token of this base URL. Cancelling the dialog or entering no value keeps the current token.
    /// </summary>
    procedure SetToken()
    begin
        BaseURLHelper.SetToken(Rec);
    end;

    /// <summary>
    /// Stores the given value as the token of this base URL. An empty value keeps the current token.
    /// </summary>
    /// <param name="Token">The personal access token.</param>
    internal procedure SetToken(Token: SecretText)
    begin
        BaseURLHelper.SetToken(Rec, Token);
    end;

    /// <summary>
    /// Deletes the token of this base URL after a confirmation.
    /// </summary>
    procedure ClearToken()
    begin
        BaseURLHelper.ClearToken(Rec);
    end;

    /// <summary>
    /// Returns whether a token is stored for this base URL.
    /// </summary>
    /// <returns>True if a token is stored; otherwise false.</returns>
    procedure HasToken(): Boolean
    begin
        exit(BaseURLHelper.HasToken(Rec));
    end;

    /// <summary>
    /// Returns the token of this base URL, or an empty value if none is stored.
    /// </summary>
    /// <returns>The token.</returns>
    internal procedure GetToken(): SecretText
    begin
        exit(BaseURLHelper.GetToken(Rec));
    end;

    /// <summary>
    /// Deletes the tokens of all base URLs in the current company. Filters on this record are ignored.
    /// </summary>
    internal procedure DeleteAllTokens()
    begin
        BaseURLHelper.DeleteAllTokens();
    end;
}
