// TaggedPart.pas
// Dynamically Modified TaggedPart.log file
// Create TaggedPart.log file for selected Part on the Current SCHDoc Sheet
// This File is Read by Parts_Frontend.accde when Tagged is Selected
// This script and the TaggedPart.Log should be in a folder on the user's machine, i.e. C Drive

// Randy Clemmons Jan 3, 2022
// https://pcbparts.blogspot.com/p/contact-us.html

Procedure TaggedPart();

Var
    CurrentSch : ISch_Sheet;
    Iterator   : ISch_Iterator;
    AComponent : ISch_Component;
    LibName    : WideString;    // DBLIB Name
    TableName  : WideString;    // Table Name
    PartID     : WideString;    // Design Item ID
    Libref     : WideString;    // Symbol LibRef
    FileName   : WideString;
    txtFile    : TextFile;
    cnt        : Integer;

 Begin

    // Initialize Variables
    LibName := '';
    TableName := '';
    PartID := '';
    Libref := '';
    FileName := 'C:\MyPartsScripts\TaggedPart.log';

    // Verify the Log File Exists
    If not FileExists(FileName) then
    begin
        // showinfo('Select Parts Frontend > Configuration > Parts Script > Enabled = Yes > Apply','File Not Found - TaggedPart.log');
        // Exit;
    end;

    // Check if schematic server exists or not.
    If SchServer = Nil Then Exit;

    // Obtain the current schematic document interface.
    CurrentSch := SchServer.GetCurrentSchDocument;
    If CurrentSch = Nil Then Exit;

    // Initialize the robots in Schematic editor.
    SchServer.ProcessControl.PreProcess(CurrentSch, '');

    // Look for components only
    Iterator := CurrentSch.SchIterator_Create;
    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));

    cnt := 0;  // initialize cnt


        AComponent := Iterator.FirstSchObject;
        While AComponent <> Nil Do
        Begin
            if AComponent.Selection = True then
            begin
               cnt := cnt + 1;
               if cnt > 1 then
               begin
                  showinfo('Please Select Only One Part', 'Tag Part');
                  Break;
               end;
               LibName : = AComponent.LibraryIdentifier;
               TableName : = AComponent.GetState_DatabaseTableName;
               PartID := AComponent.DesignItemId;
               Libref := AComponent.LibReference;
            end;
            AComponent := Iterator.NextSchObject;
        End;
        if cnt >= 1  then
        begin

         Try

           AssignFile(txtFile, FileName);
           ReWrite(txtFile);
           Write(txtFile, 'LibName := ' + LibName + #13#10);
           Write(txtFile, 'TableName := ' + TableName + #13#10);
           Write(txtFile, 'PartID := ' + PartID + #13#10);
           Write(txtFile, 'Libref := ' + Libref + #13#10);

         Finally

           CloseFile(txtFile);

           If not FileExists(FileName) then
           begin
              showinfo(FileName,'Tagged File Not Found');
           end;

           // The Showinfo Maybe Commented Out
           // showinfo(LibName + #13#10 + 'ID: ' +  PartID + #13#10 +  'Library Ref: ' +  Libref, 'Tagged Part');
        end;
        if cnt = 0 then
        begin
          showinfo('Please Select One Part', 'Tag Part');
        end;

        CurrentSch.SchIterator_Destroy(Iterator);
        CurrentSch.GraphicallyInvalidate;
        // Clean up robots in Schematic editor.
        SchServer.ProcessControl.PostProcess(CurrentSch, '');

    End;

End;


