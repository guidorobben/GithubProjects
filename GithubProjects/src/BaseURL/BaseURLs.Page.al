page 80000 "Base URLs GHP"
{
    AdditionalSearchTerms = 'GitHub Projects, Azure DevOps, token';
    ApplicationArea = All;
    Caption = 'Base URLs';
    DelayedInsert = true;
    PageType = List;
    SourceTable = "Base URL GHP";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(BaseURLs)
            {
                field(Code; Rec.Code) { }
                field(URL; Rec.URL) { }
                field("Source Type"; Rec."Source Type") { }
                field(TokenSet; TokenSet)
                {
                    Caption = 'Token Set';
                    Editable = false;
                    ToolTip = 'Specifies whether a token is set for the base URL. The token itself is never shown. Without a token, a GitHub base URL only returns public data and is limited to 60 requests per hour. An Azure DevOps base URL requires a token.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SetToken)
            {
                Caption = 'Set Token';
                Image = EncryptionKeys;
                ToolTip = 'Enter the personal access token for the selected base URL. An existing token is replaced. The token cannot be read back.';

                trigger OnAction()
                begin
                    Rec.SetToken();
                    CurrPage.Update(false);
                end;
            }
            action(ClearToken)
            {
                Caption = 'Clear Token';
                Image = Delete;
                ToolTip = 'Delete the token of the selected base URL.';

                trigger OnAction()
                begin
                    Rec.ClearToken();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(SetToken_Promoted; SetToken) { }
                actionref(ClearToken_Promoted; ClearToken) { }
            }
        }
    }

    var
        TokenSet: Boolean;

    trigger OnAfterGetRecord()
    begin
        TokenSet := Rec.HasToken();
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        TokenSet := false;
    end;
}
