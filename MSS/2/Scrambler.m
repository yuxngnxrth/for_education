function y = Scrambler(u, nS)
% Downlink scrambling
persistent hSeqGen
if isempty(hSeqGen)
 maxG=43200;
 hSeqGen = comm.GoldSequence('FirstPolynomial',[1 zeros(1, 27) 1 0 0 1],...
 'FirstInitialConditions', [zeros(1, 30) 1], ...
 'SecondPolynomial', [1 zeros(1, 27) 1 1 1 1],...
 'SecondInitialConditionsSource', 'Input port',...
 'Shift', 1600,...
 'VariableSizeOutput', true,...
 'MaximumOutputSize', [maxG 1]);
end
% Parameters to compute initial condition
RNTI = 1;
NcellID = 0;
q =0;
% Initial conditions
c_init = RNTI*(2^14) + q*(2^13) + floor(nS/2)*(2^9) + NcellID;
% Convert initial condition to binary vector
iniStates = int2bit(c_init, 31);
% Generate the scrambling sequence
nSamp = size(u, 1);
seq = step(hSeqGen, iniStates, nSamp);
seq2=zeros(size(u));
seq2(:)=seq(1:numel(u),1);
% Scramble input with the scrambling sequence
y = xor(u, seq2);