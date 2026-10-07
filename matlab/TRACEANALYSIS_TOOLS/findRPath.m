function Rpath = findRPath
    if ispc     % for PCs
        if exist("biomet_Rpath_default.m",'file')
            Rpath = biomet_Rpath_default;
        else
            pathMatlab = matlabroot;
            indY = strfind(upper(pathMatlab),[filesep 'MATLAB']);
            pathBin = fullfile(pathMatlab(1:indY-1));
            s = dir(fullfile(pathBin,'R','R-*'));
            if length(s) < 1
                error ('Cannot find location of R inside of %s\n',pathBin);
            end
            [~,N ]=sort({s(:).name});
            N = N(end);
            Rpath = fullfile(s(N).folder,s(N).name,'bin','Rscript.exe');
        end
    elseif isunix    % for Mac OS or linux
        if exist("biomet_Rpath_default.m",'file')
            Rpath = biomet_Rpath_default;
        else        
            % look for location of Rscript executable
            [status,outpath] = system('which Rscript');    
            if status   
                % can't find Rscript, need to modify system path to include 
                % where Rscript is installed (e.g. '/usr/local/bin/')
                % this might appear redundant but works with approach to use UNIX
                % "which" command, and so we don't assume path to Rscript is
                % same on every Mac
                Rloc = '/usr/local/bin';    % likely path to Rscript
                path = getenv('PATH');
                newpath = [path ':' Rloc];
                setenv('PATH',newpath);
                [~,outpath] = system('which R');
            end   
            indY = strfind(outpath,[filesep 'R']);
            pathBin = fullfile(outpath(1:indY-1));
            Rpath = fullfile(pathBin,'Rscript'); 
            % check 
            if ~isfile(Rpath)
                error ('Cannot find R in %s\n',pathBin);
            end
        end        
    end
end