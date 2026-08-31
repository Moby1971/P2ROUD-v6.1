function [im,dim,par,unsortedKspace] = importMRD(filename, reordering1, reordering2)

% Read a multidimensional MRD or SUR file, with its PPR parameters
%
%   [im, dim, par, unsortedKspace] = proud.io.importMRD(filename, reordering1, reordering2)
%
%   filename         MRD or SUR file to read
%   reordering1      'seq' or 'cen', the view order for 2D (views)
%   reordering2      'seq' or 'cen', the view order for 3D (views2)
%   im               complex data, reordered as requested
%   dim              raw dimensions, as
%                    [no_expts no_echoes no_slices no_views no_views_2 no_samples]
%   par              parameters parsed from the MRD header and the PPR block
%   unsortedKspace   the same data before reordering, for sorting schemes the
%                    class works out for itself
%
% 'cen' means the views were acquired centrically and are put back into linear
% order here; 'seq' means they were acquired in order and are left alone.
%
% Upstream history, kept because it records the dimension order the file
% format actually has:
% Description: Function to open multidimensional MRD/SUR files given a filename with PPR-parsing
% Read in MRD and SUR file formats
% Inputs: string filename, reordering1, reordering2
% reordering1, 2 is 'seq' or 'cen'
% reordering1 is for 2D (views)
% reordering2 is for 3D (views2)
% Outputs: complex data, raw dimension [no_expts,no_echoes,no_slices,no_views,no_views_2,no_samples], MRD/PPR parameters
% Author: Ruslan Garipov
% Date: 01/03/2014 - swapped views and views2 dimension - now correct
% 30 April 2014 - support for reading orientations added
% 11 September 2014 - swapped views and views2 in the array (otherwise the images are rotated)
% 13 October 2015 - scaling added as a parameter

    fid = fopen(filename,'r');      % Define the file id
    val = fread(fid,4,'int32');
    xdim = val(1);
    ydim = val(2);
    zdim = val(3);
    dim4 = val(4);
    fseek(fid,proud.Constants.MRD_OFFSET_DATATYPE,'bof');
    dataType = fread(fid,1, 'uint16');
    dataType = dec2hex(dataType);
    fseek(fid,proud.Constants.MRD_OFFSET_FOOTER,'bof');
    scaling = fread(fid,1, 'float32');
    bitsPerPixel = fread(fid,1, 'uchar');
    fseek(fid,proud.Constants.MRD_OFFSET_DIMS,'bof');
    val = fread(fid,2, 'int32');
    dim5 = val(1);
    dim6 = val(2);
    fseek(fid,proud.Constants.MRD_OFFSET_DATA,'bof');
    text = fread(fid,256);
    no_samples = xdim;
    no_views = ydim;
    no_views_2 = zdim;
    no_slices = dim4;
    no_echoes = dim5;
    no_expts = dim6;

    % Read in the complex image data
    dim = [no_expts,no_echoes,no_slices,no_views_2,no_views,no_samples];

    if size(dataType,2)>1
        onlyDataType = dataType(2);
        isComplex = 2;
    else
        onlyDataType = dataType(1);
        isComplex = 1;
    end

    switch onlyDataType
        case '0'
            dataFormat = 'uchar';
        case '1'
            dataFormat = 'schar';
        case '2'
            dataFormat = 'short';
        case '3'
            dataFormat = 'int16';
        case '4'
            dataFormat = 'int32';
        case '5'
            dataFormat = 'float32';
        case '6'
            dataFormat = 'double';
        otherwise
            dataFormat = 'int32';
    end

    % Try to read the expected amount of data at once
    num2Read = no_expts*no_echoes*no_slices*no_views_2*no_views*no_samples*isComplex;
    [m_total, count] = fread(fid,num2Read,dataFormat);

    % Check if expected size of data was read
    % If not, this means that the acquisition was prematurely stopped
    % and only part of the data is available
    if count < num2Read

        % Find the end of the data by looking for :PPL string
        textData = fileread(filename);
        targetText = ":PPL";
        amountOfData = strfind(textData,targetText);

        % Number of floats to read
        newNum2Read = (amountOfData-4)/4 - 512;

        % Reset the file position indicator to beginning of the data
        fseek(fid,proud.Constants.MRD_OFFSET_KSPACE,'bof');

        % Read the data again
        [m_total, count] = fread(fid,newNum2Read ,dataFormat);

    end

    if isComplex == 2
        a=1:floor(count/2);
        m_real = m_total(2*a-1);
        m_imag = m_total(2*a);
        clear m_total;
        m_C_tmp = m_real+m_imag*1i;
        clear m_real m_imag;
    else
        m_C_tmp = m_total;
        clear m_total;
    end

    % Pre-allocate the expected size of m_C, in case of missing data
    m_C = zeros(num2Read/isComplex,1);
    m_C(1:length(m_C_tmp)) = m_C_tmp;

    % The unsorted k-space
    unsortedKspace = m_C;

    % Shaping the data manually:
    ord=1:no_views;
    if strcmp(reordering1,'cen')
        for g=1:no_views/2
            ord(2*g-1)=no_views/2+g;
            ord(2*g)=no_views/2-g+1;
        end
    end

    ord1 = 1:no_views_2;
    ord2 = ord1;
    if strcmp(reordering2,'cen')
        for g=1:no_views_2/2
            ord2(2*g-1)=no_views_2/2+g;
            ord2(2*g)=no_views_2/2-g+1;
        end
    end

    % pre-allocate the data matrix
    m_C_1=zeros(no_expts,no_echoes,no_slices,max(ord(:)),max(ord2(:)),no_samples);

    n=0;
    for a=1:no_expts
        for b=1:no_echoes
            for c=1:no_slices
                for d=1:no_views
                    for e=1:no_views_2
                        m_C_1(a,b,c,ord(d),ord2(e),:) = m_C(1+n:no_samples+n); % sequential ordering
                        n=n+no_samples;
                    end
                end
            end
        end
    end

    clear ord;
    clear ord2;
    m_C = squeeze(m_C_1);
    clear m_C_1;
    im=m_C;
    clear m_C;
    sample_filename = char(fread(fid,120,'uchar')');
    fseek(fid,-120,'cof');
    ppr_text = char(fread(fid,Inf,'uchar')');
    fclose(fid);

    % Locate the first entry = :PPL
    pos1 = strfind(ppr_text,':PPL');
    ppr_text = ppr_text(pos1(1):end);

    % Parse fields in ppr section of the MRD file
    if numel(ppr_text)>0
        cell_text = textscan(ppr_text,'%s','delimiter',char(13));
        PPR_keywords = {'BUFFER_SIZE','DATA_TYPE','DECOUPLE_FREQUENCY','DISCARD','DSP_ROUTINE','EDITTEXT','EXPERIMENT_ARRAY','FOV','FOV_READ_OFF','FOV_PHASE_OFF','FOV_SLICE_OFF','GRADIENT_STRENGTH','MULTI_ORIENTATION','Multiple Receivers','NO_AVERAGES','NO_ECHOES','NO_RECEIVERS','noSamples','NO_SLICES','NO_VIEWS','NO_VIEWS_2','OBLIQUE_ORIENTATION','OBSERVE_FREQUENCY','ORIENTATION','PHASE_CYCLE','READ/PHASE/SLICE_SELECTION','RECEIVER_FILTER','SAMPLE_PERIOD','SAMPLE_PERIOD_2','SCROLLBAR','SLICE_BLOCK','SLICE_FOV','SLICE_INTERLEAVE','SLICE_THICKNESS','SLICE_SEPARATION','SPECTRAL_WIDTH','SWEEP_WIDTH','SWEEP_WIDTH_2','VAR_ARRAY','VIEW_BLOCK','VIEWS_PER_SEGMENT','SMX','SMY','SWX','SWY','SMZ','SWZ','VAR','PHASE_ORIENTATION','X_ANGLE','Y_ANGLE','Z_ANGLE','PPL','IM_ORIENTATION','IM_OFFSETS','lines_per_segment'};
        % PPR_type_0 keywords have text fields only, e.g. ":PPL C:\ppl\smisim\1ge_tagging2_1.PPL"
        PPR_type_0 = [23 53];
        % PPR_type_1 keywords have single value, e.g. ":FOV 300"
        PPR_type_1 = [8 42:47];
        % PPR_type_2 keywords have single variable and single value, e.g. ":noSamples no_samples, 16"
        PPR_type_2 = [4 7  15:21 25 31 33 41 49];
        PPR_type_3 = 48; % VAR keyword only (syntax same as above)
        PPR_type_4 = [28 29]; % :SAMPLE_PERIOD sample_period, 300, 19, "33.3 KHz  30 ?s" and SAMPLE_PERIOD_2 - read the first number=timeincrement in 100ns
        % PPR_type_5 keywords have single variable and two values, e.g. ":SLICE_THICKNESS gs_var, -799, 100"
        PPR_type_5 = [34 35];
        % KEYWORD [pre-prompt,] [post-prompt,] [min,] [max,] default, variable [,scale] [,further parameters ...];
        PPR_type_6 = [39 9:11 50:52]; % VAR_ARRAY and angles keywords
        PPR_type_7 = [54 55]; % IM_ORIENTATION and IM_OFFSETS (SUR only)

        par = struct('filename',filename);
        for j=1:size(cell_text{1},1)
            char1 = char(cell_text{1}(j,:));
            field_ = '';
            if ~isempty(char1)
                C = textscan(char1, '%*c%s %s', 1);
                field_ = char(C{1});
            end
            % Find matching number in PPR_keyword array:
            num = find(strcmp(field_,PPR_keywords));
            if num>0
                if find(PPR_type_3==num) % :VAR keyword
                    C = textscan(char1, '%*s %s %f');
                    field_title = char(C{1}); field_title(numel(field_title)) = [];
                    numeric_field = C{2};
                    par = setfield(par, field_title, numeric_field); %#ok<*SFLD>
                elseif find(PPR_type_1==num)
                    C = textscan(char1, '%*s %f');
                    numeric_field = C{1};
                    par = setfield(par, field_, numeric_field);
                elseif find(PPR_type_2==num)
                    C = textscan(char1, '%*s %s %f');
                    numeric_field = C{2};
                    par = setfield(par, field_, numeric_field);
                elseif find(PPR_type_4==num)
                    C = textscan(char1, '%*s %s %n %n %s');
                    field_title = char(C{1}); field_title(numel(field_title)) = []; %#ok<*NASGU>
                    numeric_field = C{2};
                    par = setfield(par, field_, numeric_field);
                elseif find(PPR_type_0==num)
                    C = textscan(char1, '%*s %[^\n]');
                    text_field = char(C{1});
                    par = setfield(par, field_, text_field);
                elseif  find(PPR_type_5==num)
                    C = textscan(char1, '%*s %s %f %c %f');
                    numeric_field = C{4};
                    par = setfield(par, field_, numeric_field);
                elseif  find(PPR_type_6==num)
                    C = textscan(char1, '%*s %s %f %c %f', 100);
                    field_ = char(C{1}); field_(end) = [];% the name of the array
                    num_elements = C{2}; % the number of elements of the array
                    numeric_field = C{4};
                    multiplier = [];
                    for l=4:numel(C)
                        multiplier = [multiplier C{l}];
                    end
                    pattern = ':';
                    k=1;
                    tline = char(cell_text{1}(j+k,:));
                    while (~contains(tline, pattern))
                        tline = char(cell_text{1}(j+k,:));
                        arr = textscan(tline, '%*s %f', num_elements);
                        multiplier = [multiplier, arr{1}']; %#ok<*AGROW>
                        k = k+1;
                        tline = char(cell_text{1}(j+k,:));
                    end
                    par = setfield(par, field_, multiplier);
                elseif find(PPR_type_7==num) % :IM_ORIENTATION keyword
                    C = textscan(char1, '%s %f %f %f');
                    field_title = char(C{1}); field_title(1) = [];
                    numeric_field = [C{2}, C{3}, C{4}];
                    par = setfield(par, field_title, numeric_field);
                end
            end
        end
        if isfield('OBSERVE_FREQUENCY','par')
            C = textscan(par.OBSERVE_FREQUENCY, '%q');
            text_field = char(C{1});
            par.Nucleus = text_field(1,:);
        else
            par.Nucleus = 'Unspecified';
        end
        par.datatype = dataType;
        file_pars = dir(filename);
        par.date = file_pars.date;
    else
        par = [];
    end
    par.scaling = scaling;

end
