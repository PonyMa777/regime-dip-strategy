function [regime,ma,slope] = classifyRegime(T,c)
% BULL: close above a rising MA; BEAR: close below a falling MA; RANGE otherwise.
% NA until both the MA and its slope exist. Uses only data up to each close.
px=T.Close; n=numel(px);
ma=movmean(px,[c.maLen-1 0]); ma(1:min(n,c.maLen-1))=NaN;
slope=nan(n,1);
if n>c.slopeDays, slope(c.slopeDays+1:end)=ma(c.slopeDays+1:end)-ma(1:end-c.slopeDays); end
regime=repmat("RANGE",n,1);
regime(px>ma & slope>0)="BULL";
regime(px<ma & slope<0)="BEAR";
regime(isnan(slope))="NA";
end
