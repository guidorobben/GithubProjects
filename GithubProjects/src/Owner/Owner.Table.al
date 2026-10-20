table 80001 "Owner GHP"
{
    AllowInCustomizations = AsReadOnly;
    Caption = 'Owner';
    DataClassification = CustomerContent;
    DrillDownPageId = "Owners GHP";
    LookupPageId = "Owners GHP";

    fields
    {
        field(1; "Base URL Code"; Code[20])
        {
            Caption = 'Base URL Code';
            NotBlank = true;
            // No Source Type filter here: the helper refuses non-GitHub base URLs with a message that explains why,
            // and a validated relation keeps renaming a base URL cascading to its owners.
            TableRelation = "Base URL GHP";
            ToolTip = 'Specifies the GitHub base URL the owner belongs to.';

            trigger OnValidate()
            begin
                OwnerHelper.CheckBaseUrl(Rec);
            end;
        }
        field(2; Name; Text[100])
        {
            Caption = 'Name';
            NotBlank = true;
            ToolTip = 'Specifies the name of the GitHub user or organization, as in https://github.com/{name}. Only letters, digits, hyphens and underscores are allowed.';

            trigger OnValidate()
            begin
                OwnerHelper.ValidateName(Rec);
            end;
        }
        field(3; "Owner Type"; Enum "Owner Type GHP")
        {
            Caption = 'Owner Type';
            ToolTip = 'Specifies whether the owner is a GitHub user or a GitHub organization. It decides which repositories are retrieved.';
        }
        field(4; "Repository Sync"; Enum "Owner Sync GHP")
        {
            Caption = 'Repository Sync';
            InitValue = Include;
            ToolTip = 'Specifies whether the repositories of the owner are retrieved. An owner set to Ignore is skipped by Update Repositories; its stored repositories are kept.';
        }
        field(10; "No. of Repositories"; Integer)
        {
            CalcFormula = count("Repository GHP" where("Base URL Code" = field("Base URL Code"), Owner = field(Name)));
            Caption = 'No. of Repositories';
            Editable = false;
            FieldClass = FlowField;
            ToolTip = 'Specifies how many repositories of the owner are stored.';
        }
    }

    keys
    {
        key(PK; "Base URL Code", Name)
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        OwnerHelper.CheckOwner(Rec);
    end;

    trigger OnModify()
    begin
        OwnerHelper.CheckOwner(Rec);
    end;

    trigger OnRename()
    begin
        OwnerHelper.RefuseRename();
    end;

    trigger OnDelete()
    begin
        OwnerHelper.DeleteRepositories(Rec);
    end;

    var
        OwnerHelper: Codeunit "Owner Helper GHP";

    /// <summary>
    /// Retrieves the repositories of all owners in the current filter from GitHub. Each owner is updated separately; failures are reported together at the end.
    /// </summary>
    procedure UpdateRepositories()
    begin
        OwnerHelper.UpdateRepositories(Rec);
    end;

    /// <summary>
    /// Retrieves the repositories of all owners in the current filter, then the issues of their eligible repositories.
    /// </summary>
    procedure UpdateRepositoriesAndIssues()
    begin
        OwnerHelper.UpdateRepositoriesAndIssues(Rec);
    end;
}
