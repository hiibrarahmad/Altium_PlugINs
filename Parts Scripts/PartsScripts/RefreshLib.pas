// RefreshLibrary.pas

// Refresh All Installed Libraries = True
// Refresh Only Current Library = False

// Randy Clemmons 2/20/2023
// https://pcbparts.blogspot.com/p/contact-us.html

Procedure RefreshLib();

Var
   IntLibMan      : IIntegratedLibraryManager;
   RefreshAll     : Boolean;

Begin

    RefreshAll := True; // True = Refresh All Installed Libraries

    IntLibMan := IntegratedLibraryManager;   // Initialize IntegratedLibraryManager
    If IntLibMan = Nil Then Exit;

    if RefreshAll then
        begin
           Client.SendMessage('IntegratedLibrary:RefreshInstalledLibraries', 'AllLibraries=true', 255, Client.CurrentView);
        end
    else
        begin
           Client.SendMessage('IntegratedLibrary:RefreshInstalledLibraries', 'AllLibraries=false', 255, Client.CurrentView);
        end
    end;

end;
