function [gyr,gyr2] = gyro(nucleus,type)

% Gyromagnetic ratio of a nucleus, in the requested units
%
%   [gyr, gyr2] = proud.util.gyro(nucleus, type)
%
%   nucleus   'H1' (default), 'C13', 'P31', 'F19', 'N15', 'SI29', 'H2' or 'E'.
%             Each is also accepted in its other spellings, so 'H', 'H1' and
%             '1H' all select hydrogen. An unrecognised name gives hydrogen
%   type      units, selected by what the string contains: 'G' divides by 1e4
%             to give per gauss, 'rad' multiplies by 2*pi. So 'Hz/T' (default),
%             'Hz/G', 'rad/Ts' and 'rad/Gs' all work
%   gyr       the ratio in the requested units
%   gyr2      the same value in all four units at once, ordered
%             [Hz/T, Hz/G, rad/Ts, rad/Gs], regardless of type
%
% Note that gyr2 ignores type, so it is the way to get several units from one
% call rather than a second copy of gyr.
%
% Gustav Strijkers
% g.j.strijkers@amsterdamumc.nl
% August 2026

    gyros=[267.5153151 67.2828 108.291 251.815 -27.116 -53.190 176085.964411 41.065 ]*10^6/(2*pi);  % Hz/T
    nucl_1 = {'H','C','P','F','N','Si','E','D'};
    nucl_2 = {'H1','C13','P31','F19','N15','SI29','E','H2'};
    nucl_3 = {'1H','13C','31P','19F','15N','29SI','E','2H'};

    if nargin < 1
        nucleus = 1; % Default H
    elseif ischar(nucleus)
        nucl2 = upper(nucleus);
        nucleus = 1; % Default H
        silmukka = 2;
        while silmukka<length(gyros)+1
            if (strcmp(nucl2,nucl_1{silmukka})|strcmp(nucl2,nucl_2{silmukka})|strcmp(nucl2,nucl_3{silmukka}))
                nucleus = silmukka;
                silmukka = length(gyros)+1;
            else
                silmukka = silmukka+1;
            end
        end
    end

    ga = 0;
    rad = 0;

    if nargin < 2
        type = 1;	% Default Hz/T
    elseif ischar(type)
        if (contains(type,'G'))
            ga = 1;
        end
        if (contains(type,'rad'))
            rad = 1;
        end
    end

    gyr = gyros(nucleus);
    gyr2 = [gyr gyr/10000 gyr*2*pi gyr*2*pi/10000];

    if rad
        gyr = gyr*2*pi;
    end

    if ga
        gyr = gyr/10000;
    end

end % Gyro
