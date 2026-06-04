try
    fprintf('Started: %s\n',mfilename);
%     diarylog
    disp(datestr(now));
    cd T:\GHG\matlab\Picarro_Beta_version
    run_picarro_ACS_daily(now-2:now-1)
    disp(datestr(now));
catch
    fprintf('*** Error in: %s ***\n',mfilename);
end
fprintf('Finished: %s\n',mfilename);
