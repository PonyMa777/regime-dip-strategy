function [T,div] = loadData(pricePath,divPath)
% Daily OHLC (Date,Open,High,Low,Close) and dividends (ExDate,Amount). Defaults: data/ next to this file.
root=fileparts(mfilename('fullpath'));
if nargin<1 || strlength(string(pricePath))==0, pricePath=fullfile(root,'data','SPY_1993_2026.csv'); end
if nargin<2 || strlength(string(divPath))==0, divPath=fullfile(root,'data','SPY_dividends.csv'); end
T=readtable(pricePath);
if ~isdatetime(T.Date), T.Date=datetime(string(T.Date),'InputFormat','yyyy-MM-dd'); end
div=table(datetime.empty(0,1),zeros(0,1),'VariableNames',{'ExDate','Amount'});
if isfile(divPath)
    div=readtable(divPath);
    if ~isdatetime(div.ExDate), div.ExDate=datetime(string(div.ExDate),'InputFormat','yyyy-MM-dd'); end
else
    warning('No dividend file at %s: shorts will not pay dividends, which overstates short returns.',divPath);
end
end
