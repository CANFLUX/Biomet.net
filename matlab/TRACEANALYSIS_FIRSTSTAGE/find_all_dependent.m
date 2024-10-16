function [trace_str_out,count]= find_all_dependent(trace_str)
%The input array of traces should contain  nonempty fields 'dependent'
%which lists traces that are dependent on each trace listed.  Any points removed or
%restored in these traces will be removed/restored in the dependent traces.
%This function is called to find the indices of each of the dependent traces
%within the list of all traces.  This function will recursively search any
%of the the dependent traces for further dependencies.
%
%  NOTE: Two traces dependent on each other is ok, even if its not a direct dependency.
%	      This function will simply ignore circular dependencies.
%
%Input:	
%			'trace_str'			-contains list of all traces present in the ini_file.
%Output:	'trace_str_out'	-contains indices of all dependent traces(and linked 
%									dependent traces) in the ini_file.
%

% Revisions
%
%  July 29, 2024 (P.Moore)
%   - With the development of #include ini files, sometimes trace_str might
%       contain traces that don't exist in the raw database. To avoid
%       problems with dependents, "& ~isempty(trc.data)" was added to the
%       conditional statement.
%  July 25, 2022 (Zoran)
%   - Change back the upper case letters TA in TA_get_index_traceList to
%   lower case ta_get_index_traceList.
%  Mar 4, 2020 (Zoran)
%   - Change to capital letters TA in TA_get_index_traceList to match the
%   file name.


trace_str(1).ind_depend = [];
list_dep = [];
for ind=1:length(trace_str)   
   trc = trace_str(ind);
   if isfield(trc.ini,'dependent') & ~isempty(trc.ini.dependent) & ~isempty(trc.data) % Added "& ~isempty(trc.data)" 2024-07-29 (P.Moore) 
      trc.ind_depend = ta_get_index_traceList(trc.ini.dependent, trace_str);     
      list_dep = [list_dep ind]; %#ok<*AGROW>
   end
   trace_str(ind) = trc;
end

count = 0;

for ind = list_dep
    try
       answer = trace_str(ind).ind_depend;
       curr = answer;
       listDone = ind;
       while ~isempty(curr)
          new_ind = [];
          listDone = [listDone curr];
          for j=curr
             count = count + 1;
             if any(find(j==list_dep))              
                temp = trace_str(j).ind_depend;
                new_ind = union(new_ind,temp);
             end   
          end
          new_ind = setdiff(new_ind,listDone);      
          curr = new_ind(:)';  % make sure curr is a row vector 20200422
          answer = union(answer,new_ind);           
       end      
       trace_str(ind).ind_depend = answer;
    catch me
        me
    end
end


trace_str_out = trace_str;
