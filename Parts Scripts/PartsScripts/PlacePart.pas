// PlacePart.pas
// Dynamically Modified Script for Placing Parts
// This File gets modified by Parts_Frontend.accde

// Randy Clemmons JAN 5, 2024
// https://pcbparts.blogspot.com

Procedure SetDocumentDirty(dummy : integer = 0);
Var
    AView           : IServerDocumentView;
    AServerDocument : IServerDocument;
Begin
    If Client = Nil Then Exit;
    // Grab the current document view using the Client's Interface.
    AView := Client.GetCurrentView;

    // Grab the server document which stores views by extracting the owner document field.
    AServerDocument := AView.OwnerDocument;

    // Set the document dirty.
    AServerDocument.Modified := True;
End;

Procedure PlacePart();

Var

    CurrentSch     : ISch_Document;
    IntLibMan      : IIntegratedLibraryManager;
    CompLoc        : WideString;
    LibType        : ILibraryType;
    LibName        : WideString;
    TableName      : WideString;
    Libref         : WideString;
    SchComp        : ISch_Component;
    Location       : TLocation;

Begin

    LibType := eLibDatabase;   // LibType = DBLIB or SVNDBLIB

    // Dynamically Modified Variables by Parts Frontend.accde
    // DBlib Library Name, TableName and Library Ref (Design ID)
    LibName := 'Parts.DbLib';
    TableName := 'Parts';
    Libref := '30000';

    If SchServer = Nil Then Exit;
    CurrentSch := SchServer.GetCurrentSchDocument;

    If (CurrentSch = Nil) or (CurrentSch.ObjectID = eSchLib) Then
    Begin
         Showinfo('Please Open a Schematic SchDoc.');
         Exit;
    End;

    // Deselect Objects to Prevent Moving Other Parts
    ResetParameters;
    AddStringParameter ('ObjectKind', 'FocusedDocument');
    RunProcess('Sch:DeSelect');
    ResetParameters;

    IntLibMan := IntegratedLibraryManager;
    If not Assigned(IntLibMan) Then Exit;

    // Initialize Schematic Robots.

    SchServer.ProcessControl.PreProcess(CurrentSch, '');
    SchServer.RobotManager.SendMessage(CurrentSch.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData);

    if LibType = eLibDatabase then
    begin
        CompLoc := IntLibMan.GetComponentLocationFromDatabase(LibName, TableName,  LibRef, '');
        if CompLoc <> '' then
        begin

            SchComp := SchServer.LoadComponentFromDatabaseLibrary(LibName, TableName, LibRef );
            if not Assigned(SchComp) then
            begin
                 Showinfo(LibName + ' - ' + TableName + #13#10 + 'Library Ref: ' +  Libref  , 'Part Not Found');
                 exit; // Get Outta Here
            end;
            if Assigned(SchComp) then
            begin

                CurrentSch.PreProcess_Import_FromUser;

                Location := Point(MilsToCoord(4000), MilsToCoord(10000) );  // XY Location of the Initial Placement
                SchComp.MoveToXY(Location.X, Location.Y);
                SchComp.SetState_Orientation := 0;      // Orientation

                CurrentSch.AddSchObject(SchComp);    // Can be used instead of the next 3 lines

                //SchServer.GetCurrentSchDocument.RegisterSchObjectInContainer(SchComp);
                //SchServer.RobotManager.SendMessage(CurrentSch.I_ObjectAddress,c_BroadCast, SCHM_PrimitiveRegistration,SchComp.I_ObjectAddress);
                //SchServer.RobotManager.SendMessage(CurrentSch.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);

                SchServer.GetCurrentSchDocument.GraphicallyInvalidate;

                SchComp.Selection := True;

                CurrentSch.PostProcess_Import_FromUser;

                SetDocumentDirty(0);  // Mark Schematic for Unsaved Changes

            end;

        end;

        if CompLoc = '' then
           begin
                Showinfo(LibName + ' - ' + TableName + #13#10 + 'Library Ref: ' +  Libref  , 'Part Not Found');
           end;
    end;

    SchServer.ProcessControl.PostProcess(CurrentSch, '');

    if CompLoc = '' then  Exit; // Part Not Found

    // Cut and Paste the Selected Part to Attach the part to the Cursor
    RunProcess ('Sch:Cut');
    RunProcess ('Sch:Paste');

end;

