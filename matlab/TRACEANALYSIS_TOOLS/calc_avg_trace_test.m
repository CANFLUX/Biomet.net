%% Test cases for calc_avg_trace
x_target = [1 2 3 4 5]';
y = [1.1 NaN 3.1 4.1 5.1;0.9 2.1 2.9 3.9 4.9;1 1.9 3 4 NaN]'

fprintf('\n\n=========================\n\n');


cntErr = 0;
% Case 1
for cnt = 1:length(x_target)
    x = x_target;
    x(cnt) = NaN;
    x(5) = NaN;
    x_r = calc_avg_trace(0:length(x)-1, x, y, -1);
    if ~all(abs(x_target-x_r)<0.1)
        if cntErr == 0
            fprintf('Gap fill data:\n');
            disp(y)
        end
        cntErr = cntErr+1;
        fprintf('Test #%d failed!\n',cnt);
        fprintf('Target output: ');
        fprintf('%6.2f ',x_target);
        fprintf('\n');
        fprintf('Actual output: ');
        fprintf('%6.2f ',x_r);
        fprintf('\n');
        fprintf('Current input: ');
        fprintf('%6.2f ',x);
        fprintf('\n');      
    end
end
if cntErr == 0
    fprintf('OK!');
end
fprintf('\n==========================\n');

