// Open Selected Symbol Library
// For DBLib or Project SCHLIB Library

// Known Limitations !!!

// DBlib Libraries the Symbols must be stored in
// the Symbols Folder. The DBlib file must must in the
// same parent folder as the Symbols Folder.

// Project Libraries must be located in the same folder
// as the Project PrjPcb file and the library names must
// match the project name.

// Randy Clemmons 7/24/2022
// https://pcbparts.blogspot.com/p/contact-us.html


Function SchLibUtilsConnectToCurrentLib() : ISch_Lib;
Begin
    Result := Nil;

    If SchServer = Nil Then
        Exit;

    Result := SchServer.GetCurrentSchDocument;

    // Check if the document is a Schematic Libary document
    If Result.ObjectID <> eSchLib Then
    Begin
        ShowError('Please open schematic library.');
        Result := Nil;
    End;
End;

Function SelectLibRef(LibRef : WideString) : Boolean;

Var
    CurrentLib : ISch_Lib;
    LibraryIterator : ISch_Iterator;
    Component : ISch_Component;

Begin

    CurrentLib := SchLibUtilsConnectToCurrentLib();

    If CurrentLib <> Nil Then
    Begin
        Try
            // Search the Library for the matching LibRef
            Result := False;  // Init Result
            LibraryIterator := CurrentLib.SchLibIterator_Create;
            LibraryIterator.AddFilter_ObjectSet(MkSet(eSchComponent));
            Component := LibraryIterator.FirstSchObject;
            While Component <> Nil Do
            Begin
                if UpperCase(Component.DesignItemId) = UpperCase(LibRef) then
                begin
                    ResetParameters;
                    RunProcess('SCH:NextComponentPart');
                    RunProcess('SCH:PreviousComponentPart');
                    CurrentLib.GraphicallyInvalidate;
                    Result := True;
                    Break; // Found Libref
                end;
                Component := LibraryIterator.NextSchObject;
            End;
        Finally
            CurrentLib.SchIterator_Destroy( LibraryIterator );
        End;
    End;

End;

Procedure SelectComponentForEdit(LibRef : WideString);
Var
    CurrentLib   : ISch_Lib;
    SchComponent : ISch_Component;

Begin

    CurrentLib := SchServer.GetCurrentSchDocument;
    If CurrentLib = Nil Then Exit;

    If CurrentLib.ObjectID <> eSchLib Then
    Begin
         ShowError('Please Open Schematic Library.');
         Exit;
    End;

    SchComponent := CurrentLib.GetState_SchComponentByLibRef(LibRef);

    If SchComponent <> Nil Then
    Begin
        CurrentLib.CurrentSchComponent.SelectedInLibrary := False;
        CurrentLib.SetState_Current_SchComponent(SchComponent);
        SchComponent.SelectedInLibrary := True;
        SchComponent.Import_FromUser();
        CurrentLib.GraphicallyInvalidate;
    End;

End;

Procedure EditSelectedSymbol;
Var
    PcbProject : IProject;
    CurrentSheet  : ISch_Document;
    Iterator      : ISch_Iterator;
    Comp          : ISch_Component;
    ImplIterator       : ISch_Iterator;
    SchImplementation  : ISch_Implementation;
    LibProject      : IPCB_Library;

    Document        : IServerDocument;
    fPath           : String;
    fName           : String;

    LibName    : String;    // DBLIB Name
    TableName  : String;    // Table Name
    PartID     : String;    // Design Item ID
    Libref     : String;    // Symbol LibRef
    retVal     : Boolean;   // Returned Value

Begin

    PcbProject := GetWorkspace.DM_FocusedProject;

    If (PcbProject = nil) then
    Begin
       showinfo('Current Project is not a PCB Project');
       exit;
    end;

    If SchServer = Nil Then Exit;
    CurrentSheet := SchServer.GetCurrentSchDocument;

    If CurrentSheet = Nil Then
       begin
          showinfo('Active Window is Not a .SchDoc File');
          exit;
    end;

    Try
        SchServer.ProcessControl.PreProcess(CurrentSheet, '');

        // Search for the selected component
        Iterator := CurrentSheet.SchIterator_Create;
        If Iterator = Nil Then Exit;

        Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));
        Try
            Comp := Iterator.FirstSchObject;
            While Comp <> Nil Do
            Begin
                If Comp.Selection Then Break;
                Comp := Iterator.NextSchObject;
            End;

        Finally
            Currentsheet.SchIterator_Destroy(iterator);
        End;

        If Comp = Nil Then
        begin
             Showinfo('Please Select a Part.');
             Exit;  // No selected component found then exit
        end;

        ImplIterator := Comp.SchIterator_Create;
        Try
            SchImplementation := ImplIterator.FirstSchObject;
            While SchImplementation <> Nil Do
            Begin
                  Libref := Comp.LibReference;

                  // Try to Get Path to Component Library
                  fPath := IntegratedLibraryManager.FindComponentLibraryPath(Comp.LibIdentifierKind, Comp.LibraryIdentifier, Comp.DesignItemID);

                  // Create Full SCHLIB File Path using the DBLIB Library Path
                  If Pos('.SCHLIB',UpperCase(fPath)) = 0 then
                  begin
                     fPath : = ExtractFilePath(fPath) + 'Symbols\' + Libref + '.SCHLIB'; // Build DBLib Library Path
                  end;

                  // Try Project SCHLIB if the DBLIb is Not Found
                  If not FileExists(fPath) then // Build Path to Installed Project SCHLIB
                  begin
                     PcbProject := GetWorkspace.DM_FocusedProject;
                     fPath := ExtractFilePath(PcbProject.DM_ProjectFullPath);
                     fName := ExtractFileNameFromPath(PcbProject.DM_ProjectFileName) + '.SCHLIB';
                     fPath := fPath + fName;
                     Libref := Comp.DesignItemId;
                     LibName := ExtractFileNameFromPath(PcbProject.DM_ProjectFileName);
                  end;

                  // Verify the File Exists
                  If not FileExists(fPath) then
                  begin
                     LibName : = Comp.LibraryIdentifier;
                     TableName : = Comp.GetState_DatabaseTableName;
                     PartID := Comp.DesignItemId;
                     Libref := Comp.LibReference;
                     // showinfo(LibName + #13#10 + 'ID: ' +  PartID + #13#10 +  'Library Ref: ' +  Libref, fPath);
                     Break;
                  end;

                  If Document <> Nil Then
                     Break;  // Exit While Loop After Looking at Only One Part

                  SchImplementation := ImplIterator.NextSchObject;
            End;
        Finally
            Comp.SchIterator_Destroy(ImplIterator);
        End;

    Finally
        SchServer.ProcessControl.PostProcess(CurrentSheet, '');
    End;

    CurrentSheet.GraphicallyInvalidate;

    If FileExists(fPath) then
    begin

        // Open the SchLib File
        LibProject := GetWorkspace.DM_OpenProject(fPath, true);

        // Select the Current Symbol in Library First
        SelectComponentForEdit(LibRef);

        // Then Select Part LibRef in the Library Panel
        retVal := SelectLibRef(LibRef);

        // Zoom ALL for Max Zoom    // ZA Shortcut
        Client.SendMessage('SCH:Zoom', 'Action=All', 255, Client.CurrentView);

    end
    else
    begin
        showinfo('Install Library '+ #13#10 + 'or' + #13#10 + 'Make and Save Project Library', 'Library Not Found');
    end;

End;
