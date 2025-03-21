function [Agg_Out,Start_tv,Start_dt,Map_to_Group,Map_from_Group] = Resample(x,tv_in,interval,stats,missing);
    arg_default('interval','day')
    arg_default('stats',{'mean','std','count'})
    arg_default('missing',0)
    if missing == 1
        nan_procedure = 'includenan';
    else
        nan_procedure = 'omitnan';
    end
    % Since clean_tv starts at 00:30 instead of 00:00 each year 
    tv_shift = tv_in-tv_in(2)+tv_in(1);
    DateTime = datetime(tv_shift,"ConvertFrom","datenum");
    DateTime = dateshift(DateTime, 'end', 'minute');

    Date_Group = dateshift(DateTime,'start',interval);
    
    Map_to_Group = findgroups(Date_Group);
    Start_tv = splitapply(@min,tv_in,Map_to_Group);
    Start_dt = splitapply(@min,Date_Group,Map_to_Group);
    Map_from_Group = splitapply(@min,Map_to_Group,Map_to_Group);


    stat_funcs = { ...
        @(x)[mean(x,nan_procedure)] ...
        @(x)[std(x,nan_procedure)] ...
        @(x)[sum(isfinite(x))] ...
        @(x)[max(x)] ...
        @(x)[min(x)] ...
        @(x)[max(x)-min(x)] ...
        @(x)[sum(x,nan_procedure)] ...
        @(x)[median(x,nan_procedure)] ...
        @(x)[x(1)] ...
        @(x)[x(end)] ...
        @(x)[mean(diff(x),nan_procedure)] ...
        @(x)[quantile(x,0.75)-quantile(x,0.25)] ...
        };
    names = [...
            "mean", ...
            "std", ...
            "count" ...
            "max" ...
            "min" ...
            "range" ...
            "sum" ...
            "median" ...
            "first" ...
            "last" ...
            "slope" ...
            "iqr" ...
            ];

    d = dictionary(names,stat_funcs);

    Agg_Out = NaN(length(Start_tv),length(stats));
    for s=1:length(stats)
        stat = lower(stats(s));
        f = d(stat);
        Agg_Out(:,s) = splitapply(f{1},x,Map_to_Group);
    end
end