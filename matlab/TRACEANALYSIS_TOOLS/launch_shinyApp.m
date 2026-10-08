function launch_shinyApp(biomet_db,shinyApp_workDir)

arg_default('biomet_db',biomet_database_default)
arg_default('shinyApp_workDir',"C:\Biomet.net\R\canflux_RShiny_app\")

% Environment variable used to let the shinyApp know where the database is located.
setenv('BIOMET_DB',biomet_db)

% Full path of R executable
R_exe = findRPath;

% Full path of shinyApp R file to launch
shinyApp_pth = fullfile(shinyApp_workDir,'app.R');

if ispc
    shinyApp_workDir = regexprep(shinyApp_workDir,'\','/');
    shinyApp_pth = regexprep(shinyApp_pth,'\','/');
end

% Command to execute using system()
if ispc
    cmd = sprintf('cd /d "%s" && "%s" -e "shiny::runApp(''%s'', launch.browser=TRUE)" &',...
        shinyApp_workDir,R_exe,shinyApp_pth);
elseif isunix
    cmd = sprintf('cd "%s" && "%s" -e "shiny::runApp(''%s'', launch.browser=TRUE)" &',...
        shinyApp_workDir,R_exe,shinyApp_pth);
end

system(cmd);