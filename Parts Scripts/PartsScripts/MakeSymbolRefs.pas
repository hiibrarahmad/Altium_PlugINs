// Purpose: Get LibReference for Parts Placed from a Database Library or Vault

// Randy Clemmons 2017
// https://pcbparts.blogspot.com/p/contact-us.html

Var
    cnt        : Variant;


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
{..............................................................................}

{..............................................................................}
{ Update a User Parameter Named Symbol Ref for each Component on a Sheet       }
{ Randy Clemmons 2017                                                          }
{..............................................................................}

Procedure MakeSymbolRef(dummy : integer = 0);
Var
    CurrentSch : ISch_Sheet;
    Iterator   : ISch_Iterator;
    PIterator  : ISch_Iterator;
    AComponent : ISch_Component;
    Parameter  : ISch_Parameter;
    DirtyFlag  : boolean;

    paramX          : Integer;
    paramY          : Integer;
    paramYOrig      : Integer;

Begin
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

    Try
        AComponent := Iterator.FirstSchObject;
        While AComponent <> Nil Do
        Begin
            Try
                // ShowInfo( AComponent.DesignItemId , 'Design ID');
                PIterator := AComponent.SchIterator_Create;
                PIterator.AddFilter_ObjectSet(MkSet(eParameter));
                Parameter := PIterator.FirstSchObject;
                While Parameter <> Nil Do
                Begin
                    if Parameter.Name = 'Symbol Ref' then
                    begin
                       cnt := cnt +1;

                       SchServer.RobotManager.SendMessage(Parameter.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData );

                       if Parameter.Text <> AComponent.LibReference then
                       begin
                          Parameter.Text := AComponent.LibReference;
                       end;

                       SchServer.RobotManager.SendMessage(Parameter.I_ObjectAddress, c_BroadCast, SCHM_EndModify, c_NoEventData);
                       DirtyFlag := True;

                    end;
                    Parameter:= PIterator.NextSchObject;
                End;
            Finally
                AComponent.SchIterator_Destroy(PIterator);
            End;

            // Send Component updated message to robot process
            SchServer.RobotManager.SendMessage(AComponent.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData);

            AComponent := Iterator.NextSchObject;
        End;

    Finally
        CurrentSch.GraphicallyInvalidate;
        CurrentSch.SchIterator_Destroy(Iterator);
    End;

    // Clean up robots in Schematic editor.
    SchServer.ProcessControl.PostProcess(CurrentSch, '');

    if DirtyFlag = True then
    begin
       SetDocumentDirty(0);
    end;

End;

Procedure AddParameter(ParameterName : String);
Var
    CurrentSch : ISch_Sheet;
    Iterator   : ISch_Iterator;
    PIterator  : ISch_Iterator;
    AComponent : ISch_Component;
    Parameter  : ISch_Parameter;
    DirtyFlag  : boolean;

    Param      : ISch_Parameter;
    ParmFound  : boolean;

Begin
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

    Try
        AComponent := Iterator.FirstSchObject;
        While AComponent <> Nil Do
        Begin
            Try
                ParmFound := False; // Init
                PIterator := AComponent.SchIterator_Create;
                PIterator.AddFilter_ObjectSet(MkSet(eParameter));
                Parameter := PIterator.FirstSchObject;
                While Parameter <> Nil Do
                Begin
                    if Parameter.Name = ParameterName then
                    begin
                       ParmFound := True;
                       Break;
                    end;
                    Parameter:= PIterator.NextSchObject;
                End;
            Finally
                AComponent.SchIterator_Destroy(PIterator);
            End;

            if ParmFound = False then
            begin
                 // Add the parameter to the component
                 Param := SchServer.SchObjectFactory (eParameter, eCreate_Default);
                 Param.Name := ParameterName;
                 Param.ShowName := False;
                 Param.Text     := '';
                 Param.IsHidden := True;

                 SchServer.RobotManager.SendMessage(AComponent.I_ObjectAddress, c_BroadCast, SCHM_BeginModify, c_NoEventData);
                 AComponent.AddSchObject(Param);
                 SchServer.RobotManager.SendMessage(AComponent.I_ObjectAddress, c_BroadCast, SCHM_EndModify  , c_NoEventData);

                 SchServer.RobotManager.SendMessage(AComponent.I_ObjectAddress, c_BroadCast, SCHM_PrimitiveRegistration, Param.I_ObjectAddress);
            end;

            AComponent := Iterator.NextSchObject;
        End;

    Finally
        CurrentSch.GraphicallyInvalidate;
        CurrentSch.SchIterator_Destroy(Iterator);
    End;

    // Clean up robots in Schematic editor.
    SchServer.ProcessControl.PostProcess(CurrentSch, '');

    if DirtyFlag = True then
    begin
       SetDocumentDirty(0);
    end;

End;


procedure MakeSymbolRefs;
// Open Each Schematic Sheet in a Project and Call MakeSymbolRef
var

   WS         : IWorkspace;
   PcbProject : IProject;
   DocNum     : Integer;

begin

   PcbProject := GetWorkspace.DM_FocusedProject;
   if PcbProject = nil then exit;

   If (PcbProject = nil) then
   Begin
      ShowMessage('Current Project is not a PCB Project');
      exit;
   end;

   If (AnsiUpperCase(ExtractFileExt(PCBProject.DM_ProjectFileName)) <> '.PRJPCB') then
   Begin
      ShowMessage('Current Project is not a PCB Project');
      exit;
   end;

   cnt := 0;

   For DocNum := 0 to PcbProject.DM_LogicalDocumentCount - 1 do

      if (PcbProject.DM_LogicalDocuments(DocNum).DM_DocumentKind = 'SCH') and (Client.IsDocumentOpen(PcbProject.DM_LogicalDocuments(DocNum).DM_FullPath)) then
      Begin
         Client.ShowDocument(Client.OpenDocument('Sch', PcbProject.DM_LogicalDocuments(DocNum).DM_FullPath));
         AddParameter ('Symbol Ref');
         MakeSymbolRef (0);
      end;

      if cnt = 0 then
      begin
         ShowInfo('Symbol Ref - Not Found', 'Missing Parameter');
      end;

      if cnt > 0 then
      begin
         // Need to Save > Close > Open SchDocs
         ShowInfo('Symbol Refs Updated' ,'Make Symbol Refs');
      end;

end;




{..............................................................................}


