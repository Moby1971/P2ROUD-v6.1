function v = vec(x)

% Flatten an array into a column vector
%
%   v = vec(x)
%
%   x   array of any size and dimensionality
%   v   numel(x) x 1 column vector, the elements of x in column-major order
%
% Exactly x(:), as a function, so it can be applied to an expression without
% assigning it to a variable first.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    v = reshape(x, numel(x), 1);

end % vec
