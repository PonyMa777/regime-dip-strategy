function c = regimeConfig()
% Project 2 parameters. Returns/fees/rates are decimal fractions.
c.initialCash = 100000;
% Chan signals (same as Project 1, see lib/)
c.fastMA = 5;
c.slowMA = 10;
c.forceMeasure = 'area';
c.useBuy = [true true true];   % 1B / 2B / 3B open longs in BULL and RANGE
c.useSell = [true true true];  % 1S / 2S / 3S open shorts in BEAR when bearMode = 'short'
% Regime: BULL = close above a rising MA, BEAR = close below a falling MA, else RANGE
c.maLen = 200;
c.slopeDays = 20;
c.bearMode = 'short';          % 'long' (= Project 1), 'none' (no new trades), 'short'
c.tradeWithoutRegime = false;  % trade during the MA warm-up (only for the Project 1 equivalence test)
% Execution
c.cashFraction = 1.00;
c.feeRate = 0.0005;
c.slippageRate = 0.0005;
c.takeProfit = 0.015;          % long: +1.5%, short: -1.5% from the fill
c.stopLoss = 0.05;             % long: -5%,   short: +5% from the fill; gaps can lose more
c.borrowRate = 0.005;          % short borrow fee, annual, on entry notional, per trading day / 252
c.creditLongDividends = true;  % longs receive, shorts pay, dividends on ex-dates held through
end
