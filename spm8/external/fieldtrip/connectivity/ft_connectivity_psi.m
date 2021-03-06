function [c, v, n] = ft_connectivity_psi(input, varargin)

% FT_CONNECTIVITY_PSI computes the phase slope index from a data-matrix
% containing a cross-spectral density, according to FIXME include reference
%
% Use as
%   [c, v, n] = ft_connectivity_psi(input, varargin)
%
% The input data input should be organized as:
%   Repetitions x Channel x Channel (x Frequency) (x Time)
% or
%   Repetitions x Channelcombination (x Frequency) (x Time)
%
% The first dimension should be singleton if the input already contains
% an average
%
% Additional input arguments come as key-value pairs:
%
% hasjack  0 or 1 specifying whether the Repetitions represent
%                   leave-one-out samples
% feedback 'none', 'text', 'textbar' type of feedback showing progress of
%                   computation
% dimord          specifying how the input matrix should be interpreted
% powindx
% normalize
% nbin            the number of frequency bins across which to integrate
%
% The output c contains the correlation/coherence, v is a variance estimate
% which only can be computed if the data contains leave-one-out samples,
% and n is the number of repetitions in the input data.
%
% This is a helper function to FT_CONNECTIVITYANALYSIS
%
% See also FT_CONNECTIVITYANALYSIS

% Copyright (C) 2009-2010 Donders Institute, Jan-Mathijs Schoffelen
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id: ft_connectivity_psi.m 2688 2011-01-28 09:42:53Z roboos $

hasjack   = keyval('hasjack',   varargin{:}); if isempty(hasjack),  hasjack = 0; end
feedback  = keyval('feedback',  varargin{:}); if isempty(feedback), feedback = 'none'; end
dimord    = keyval('dimord',    varargin{:});
powindx   = keyval('powindx',   varargin{:});
normalize = keyval('normalize', varargin{:}); if isempty(normalize), normalize = 'no'; end
nbin      = keyval('nbin',      varargin{:});

if isempty(dimord)
  error('input parameters should contain a dimord');
end

if (length(strfind(dimord, 'chan'))~=2 || ~isempty(strfind(dimord, 'pos'))>0) && ~isempty(powindx),
  %crossterms are not described with chan_chan_therest, but are linearly indexed
  
  siz = size(input);
  
  outsum = zeros(siz(2:end));
  outssq = zeros(siz(2:end));
  pvec   = [2 setdiff(1:numel(siz),2)];
  
  ft_progress('init', feedback, 'computing metric...');
  %first compute coherency and then phaseslopeindex
  for j = 1:siz(1)
    ft_progress(j/siz(1), 'computing metric for replicate %d from %d\n', j, siz(1));
    c      = reshape(input(j,:,:,:,:), siz(2:end));
    p1     = abs(reshape(input(j,powindx(:,1),:,:,:), siz(2:end)));
    p2     = abs(reshape(input(j,powindx(:,2),:,:,:), siz(2:end)));
    
    p      = ipermute(phaseslope(permute(c./sqrt(p1.*p2), pvec), nbin, normalize), pvec);
    
    outsum = outsum + p;
    outssq = outssq + p.^2;
  end
  ft_progress('close');
  
elseif length(strfind(dimord, 'chan'))==2 || length(strfind(dimord, 'pos'))==2,
  %crossterms are described by chan_chan_therest
  
  siz = size(input);
  
  outsum = zeros(siz(2:end));
  outssq = zeros(siz(2:end));
  pvec   = [3 setdiff(1:numel(siz),3)];
  
  ft_progress('init', feedback, 'computing metric...');
  for j = 1:siz(1)
    ft_progress(j/siz(1), 'computing metric for replicate %d from %d\n', j, siz(1));
    p1  = zeros([siz(2) 1 siz(4:end)]);
    p2  = zeros([1 siz(3) siz(4:end)]);
    for k = 1:siz(2)
      p1(k,1,:,:,:,:) = input(j,k,k,:,:,:,:);
      p2(1,k,:,:,:,:) = input(j,k,k,:,:,:,:);
    end
    c      = reshape(input(j,:,:,:,:,:,:), siz(2:end));
    p1     = p1(:,ones(1,siz(3)),:,:,:,:);
    p2     = p2(ones(1,siz(2)),:,:,:,:,:);
    p      = ipermute(phaseslope(permute(c./sqrt(p1.*p2), pvec), nbin, normalize), pvec);
    outsum = outsum + p;
    outssq = outssq + p.^2;
  end
  ft_progress('close');
  
end

n = siz(1);
c = outsum./n;

if n>1,
  if hasjack
    bias = (n-1).^2;
  else
    bias = 1;
  end
  
  v = bias*(outssq - (outsum.^2)./n)./(n - 1);
else
  v = [];
end

%---------------------------------------
function [y] = phaseslope(x, n, norm)

m   = size(x, 1); %total number of frequency bins
y   = zeros(size(x));
x(1:end-1,:,:,:,:) = conj(x(1:end-1,:,:,:,:)).*x(2:end,:,:,:,:);

if strcmp(norm, 'yes')
  coh = zeros(size(x));
  coh(1:end-1,:,:,:,:) = (abs(x(1:end-1,:,:,:,:)) .* abs(x(2:end,:,:,:,:))) + 1;
  %FIXME why the +1? get the coherence
  for k = 1:m
    begindx = max(1,k-n);
    endindx = min(m,k+n);
    y(k,:,:,:,:) = imag(sum(x(begindx:endindx,:,:,:,:)./coh(begindx:endindx,:,:,:,:)));
  end
else
  for k = 1:m
    begindx = max(1,k-n);
    endindx = min(m,k+n);
    y(k,:,:,:,:) = imag(sum(x(begindx:endindx,:,:,:,:)));
  end
end
