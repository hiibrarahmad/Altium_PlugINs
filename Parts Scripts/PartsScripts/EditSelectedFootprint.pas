// Edit Selected Footprint
// Purpose Open the selected Footprint in the Installed PCBLIB or DBLIB
// For DBLib and Project PCBLib

// References
// https://techdocs.altium.com/display/SCRT/PCB+API+Design+Objects+Interfaces
// https://techdocs.altium.com/display/SCRT/IntLib+API+Manager+Interfaces

// DBlib Libraries the Footprints must be stored in
// the Footprints Folder. The DBlib file must must in the
// same parent folder as the Footprints Folder.

// Project Libraries must be located in the same folder
// as the Project PrjPcb file and the library names must
// match the project name.

// Randy Clemmons JAN 2, 2021
// https://pcbparts.blogspot.com/p/contact-us.html

Function InstalledLib(InLibName: String): String;
// Input Installed Lib Name
// Return Path of Installed DBLib

Var

   IntLibMan      : IIntegratedLibraryManager;
   CurrLib        : Integer;  // Lib Counter
   LibCount;
   LibName;
   LibPath;

Begin

    IntLibMan := IntegratedLibraryManager;   // Initialize IIntegratedLibraryManager
    If IntLibMan = Nil Then Exit;
    LibCount := IntLibMan.InstalledLibraryCount; // Installed Lbrary Counter
    CurrLib : = 0;
    Result := 'Not Found';
    While CurrLib < LibCount do  // Loop through Installed libraries
    begin
        LibPath := IntLibMan.InstalledLibraryPath(CurrLib); // Library path
        LibName := ExtractFileName(LibPath); // Lib Name
        if LibName = InLibName then // Found DBLib Installed
         begin
            Result := ExtractFilePath(LibPath);
            Break;
        end;
        CurrLib := CurrLib + 1;
    end;

end;

Procedure EditSelectedFootprint;

var
    Board           : IPCB_Board;
    Iterator        : IPCB_BoardIterator;
    ThisObject      : IPCB_Component;
    ThisLibrary     : String;
    Document        : IServerDocument;
    fpath;
    fName;

Begin
    Board := PCBServer.GetCurrentPCBBoard;
    if Board = nil then
    begin
         ShowMessage('Active Window is Not a .PcbDoc File');
         exit;
    end;
    try
        // Find the object(s) of interest
        Iterator := Board.BoardIterator_Create;
        Iterator.SetState_FilterAll;
        Iterator.Addfilter_ObjectSet(mkSet(eComponentObject));
        ThisObject := Iterator.FirstPCBObject;
        while (ThisObject <> Nil) do
        begin
            If ThisObject.Selected = True then
            begin

                // First Try File Path for Footprint Sourced from Installed DBLIB or SVNDBLIB Library
                If Pos('DBLIB',UpperCase(ThisObject.SourceComponentLibrary)) > 0 then
                begin
                   // Build Path to Installed DBLIB\Footprint File
                   ThisLibrary := ThisObject.SourceComponentLibrary;  // Component Source DBLib
                   fPath := InstalledLib(ThisLibrary);
                   ThisLibrary := fPath + 'Footprints\' + ThisObject.Pattern + '.PCBLIB';
                end;

                // Next Try the Footprint Path shown in the PcbDoc
                If not FileExists(ThisLibrary) then
                begin
                     ThisLibrary := ThisObject.SourceFootprintLibrary;  // Footprint Source Library
                     // showinfo(ThisLibrary,'Selected Footprint');
                end;

                // Last Try Project PCBLIB if Footprint Files was Not Found
                If not FileExists(ThisLibrary) then
                begin
                    // Build Path to Installed Project PCBLIB
                    fName := ExtractFileNameFromPath(Board.FileName);
                    fpath := ExtractFilePath(Board.FileName);
                    ThisLibrary := fpath + fName + '.PCBLIB';
                end;

                // Verify the PCBLIB File Exists
                If not FileExists(ThisLibrary) then
                begin
                    showinfo('Install ' + ThisObject.SourceComponentLibrary + #13#10 + 'or' + #13#10 + 'Make and Save ' + fName + '.PCBLIB',ThisObject.Pattern + ' - Not Found');
                    Break;
                end;

                Document := Client.OpenDocument('PCBLIB',ThisLibrary);
                If Document <> Nil Then
                    Client.ShowDocument(Document); // Open the Foorprint Library

                // Open the selected footprint
                ResetParameters;
                AddStringParameter('FileName',ThisLibrary);
                AddStringParameter('Footprint', ThisObject.Pattern);
                RunProcess('PCB:GotoLibraryComponent');

                // Show All Used Layers
                ResetParameters;
                AddStringParameter('SetIndex','0');
                RunProcess('PCB:ManageLayerSets');

                Break;  // Exit While Loop After Displaying First Selected Part

            end;
            ThisObject := Iterator.NextPCBObject;
        end;
    finally
        Board.BoardIterator_Destroy(Iterator);
    end;
End;




