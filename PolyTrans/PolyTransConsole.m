%----------------------------------------------------------------------
% PolyTransConsole - Implementation of CS211 PEX 3 Part 1
%   Polygon display tool that uses matrix multiplication 
%   and matrix transformations to demonstrate matrix manip,
%   text file i/o, basic computer graphics, GUI callbacks, 
%   sub-functions, parameter passing, and persistent variables.
%
%      By: Maj Kevin Owens / 27 Apr 2014
%
%  INPUTS: name.obj - text file of vertices defining a polygon
%          name.ops - text file of transform IDs
%
% OUTPUTS: same as inputs
%----------------------------------------------------------------------

%------------------------- Primary Function ---------------------------
function PolyTransConsole()

    % Default polygon - Square
    % row 1 = x coords; row 2 = y coords; row 3 = transform unities
    Poly.M = [ -50 50 50 -50; -50 -50 50 50];
    Poly.M(3,:)=ones(1,size(Poly,2)); % need a row of 1's for transforms
    Poly.Name = 'Square';    
    
    % Create the figure once and update it with each subsequent call
    fig = figure();
    set(fig, 'Name', Poly.Name, 'NumberTitle', 'Off');
    DrawPoly(Poly);

    % Run menu interface
    while true

        fprintf( '\nMenu\n\n' );
        fprintf( ' 1: Load Object\n' );
        fprintf( ' 2: Move Object Up\n' );
        fprintf( ' 3: Move Object Down\n' );
        fprintf( ' 4: Move Object Left\n' );
        fprintf( ' 5: Move Object Right\n' );
        fprintf( ' 6: Rotate Object Clockwise\n' );
        fprintf( ' 7: Rotate Object Counterclockwise\n' );
        fprintf( ' 8: Scale Object Up\n' );
        fprintf( ' 9: Scale Object Down\n' );
        fprintf( '10: Save Operations\n' );
        fprintf( '11: Load/Play Operations\n' );
        fprintf( '12: Replay Operations\n' );
        fprintf( '13: Reset\n' );
        fprintf( ' 0: Quit\n\n' );

        Op = str2double(input( 'Choice: ', 's' ));

        if isempty(Op)
            fprintf( '\nInvalid choice.\n\n' );
            continue;
        elseif Op == 0
            close(fig);
            break;
        end
        
        Poly = DoMenuOp(Op, Poly); % execute option
        
    end

end % pex3template

%----------------------------------------------------------------------
% USAGE: Poly = DoOp(Op, Poly)
%
% DESCRIPTION: Executes the given option on the polygon.  Option
% corresponds to 
%
% INPUTS:   Op - menu option  
%           Poly.M - (2,:) matrix of x- and y-value pairs for poly vertices
% 
% OUTPUTS:  Poly - as input or as modified by transform
%----------------------------------------------------------------------
function Poly = DoMenuOp(Op, Poly)

    persistent TransOps; % holds transform options user has selected
    
    persistent OrigPoly; % polygon as initialized/loaded
    if isempty(OrigPoly)
        OrigPoly = Poly;
    end
        
    switch (Op)
        
        case 1 % load polygon
            [FileName,PathName,FilterIndex] = uigetfile('*.obj','Open Object File');
            if ~ FilterIndex == 0
                OrigPoly = LoadPoly( sprintf('%s%s', PathName, FileName) );
                Poly = OrigPoly;
            end
            DrawPoly(Poly);
           
        case { 2, 3, 4, 5, 6, 7, 8, 9 } % transform ops
            TransOps(end+1) = Op; % save operation
            DoTransOp(Op);
            DrawPoly(Poly);
            
        case 10 % save transform operations
            [FileName,PathName,FilterIndex] = uiputfile('*.ops', ...
                'Save Operations File');
            if ~ FilterIndex == 0
                dlmwrite( sprintf('%s%s', PathName, FileName), TransOps);
            end
            
        case 11 % load and play transform operations
            [FileName,PathName,FilterIndex] = uigetfile('*.ops', ...
                'Open Operations File');
            if ~ FilterIndex == 0
                TransOps = dlmread(sprintf('%s%s', PathName, FileName));
                DoTransOps();
            end
            
        case 12 % replay ops
            Poly = OrigPoly;
            DrawPoly(Poly);
            DoTransOps();
            
        case 13 % reset to original polygon and clear ops history
            Poly = OrigPoly;
            DrawPoly(Poly);
            TransOps = [];
            
        otherwise
            fprintf( '\nInvalid choice.\n\n' );

    end

    %----------------------------------------------------------------------
    % DESCRIPTION: Performs specified transform operation.
    %----------------------------------------------------------------------
    function DoTransOp(Op)

        persistent TMX; % transformation matrices mapped to menu options
        if isempty(TMX)
            TMX = { [], ...                                 % placeholder
                [1 0 0; 0 1 10; 0 0  1], ...                % up
                [1 0 0; 0 1 -10; 0 0 1], ...                % down
                [1 0 -10; 0 1 0; 0 0 1], ...                % left
                [1 0 10; 0 1  0; 0 0  1], ...               % right
                [cos(pi / 6.0), sin(pi / 6.0), 0; ...       % clockwise
                    -sin(pi / 6.0), cos(pi / 6.0), 0; 0 0 1], ...
                [cos(pi / 6.0), -sin(pi / 6.0), 0; ...      % c-clockwise
                    sin(pi / 6.0), cos(pi / 6.0), 0; 0 0 1], ...
                [1.2, 0, 0; 0, 1.2, 0; 0, 0, 1], ...        % scale up
                [0.8, 0, 0; 0, 0.8, 0; 0, 0, 1]             % scale down
            };
        end

        Poly.M = MXmult(TMX{Op}, Poly.M);
        DrawPoly(Poly);

    end
    
    %----------------------------------------------------------------------
    % DESCRIPTION: Plays series of transformation operations.
    %----------------------------------------------------------------------
    function DoTransOps()
        
        for i = 1:length(TransOps)
            pause(0.05);
            DoTransOp(TransOps(i));
        end
        
    end

end

%----------------------------------------------------------------------
% USAGE: [Result] = MXmult(A, B)
%
% DESCRIPTION: Performs linear algebra multiplication of matrices A 
%              and B.  Does not use the builtin matrix multiplication
%              operator.  Assumes check for correct dimensions
%              on the matrices is done prior to calling MXmult.
%
% INPUTS:   A - 2D matrix  
%           B - 2D matrix
% 
% OUTPUTS:  Result - linear algebra multiplication of two matrices
%----------------------------------------------------------------------
function Result = MXmult(A,B)

    Result = zeros(size(A,1), size(B,2));
    for Ar = 1:size(A,1) % for each row in A
        for Bc = 1:size(B,2) % for each col in B
            
            % sum element-wise product of row in A and col in B
            for Ac = 1:size(A,2) % for each col in A
                Result(Ar,Bc) = Result(Ar,Bc) + ...
                    A(Ar,Ac) * B(Ac,Bc);
            end
            
        end
    end
    
    % A(r, c)      Illustration of iteration over the first row in A,
    %    B(r, c)   where A is a 3x2 and B is a 2x4.
    %   1  1  1    
    %   1  2  1    Iteration occurs
    %   1  1  2    first over A(r,:) (first column)
    %   1  2  2     then over B(:,c) (third column)
    %   1  1  3     then over A(:,c) (second column, same as B(r,:))
    %   1  2  3
    %   1  1  4
    %   1  2  4

end

%----------------------------------------------------------------------
% USAGE: DrawObject(Poly)
%
% DESCRIPTION: Draws/fills the specified polygon.
%
% INPUTS:   Poly.M - (2,:) matrix of x- and y-value pairs for poly vertices
%           Poly.Name - The polygon name to display in the window title
% 
% OUTPUTS:  A figure window containing the specified polygon
%----------------------------------------------------------------------
function DrawPoly(Poly)

    fill(Poly.M(1,:),Poly.M(2,:),'b');
    Extent = 500; %max(max(abs(Poly.M))) * 1.5; % furthest extent from origin
    axis([-Extent Extent -Extent Extent]);

end

%----------------------------------------------------------------------
% USAGE: Poly = LoadObject(FileName)
%
% DESCRIPTION: Creates a polygon object from a file.
%
% INPUTS:  FileName - path+name of a text file with the following format:
%               First line: name of the polygon
%               Remaining lines: x-y vertice pairs of format '%f %f'
% 
% OUTPUTS: Poly - a structure containing:
%                 .M - 3 row-matrix: first row x-coords, second row y-coords,
%                      third row of ones for transforms
%                 .Name - name of the polygon read from the first line
%----------------------------------------------------------------------
function Poly = LoadPoly(FileName)

    FID = fopen(FileName, 'rt');
    Poly.Name = fgetl(FID); % first line is object name (can include spaces)
    Coords = textscan(FID, '%f %f'); % remaining lines are x-y coord pairs
    Poly.M = [Coords{1} Coords{2}]'; % cell array -> 2-row matrix
    Poly.M(3,:)=ones(1,size(Poly,2)); % 3rd row of ones for transforms
    fclose(FID);

end
