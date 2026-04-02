function y=TurboEncoder(u, intrlvrIndices)
persistent Turbo
if isempty(Turbo)
 Turbo = comm.TurboEncoder('TrellisStructure', poly2trellis(4, [13 15], 13), ...
 'InterleaverIndicesSource','Input port');
end
y=step(Turbo, u, intrlvrIndices);