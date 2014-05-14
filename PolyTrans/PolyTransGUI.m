%----------------------------------------------------------------------
% PolyTransGUI - Implementation of CS211 PEX 3 Part 2
%   Polygon display tool that uses matrix multiplication 
%   and matrix transformations to demonstrate matrix manip,
%   text file i/o, basic computer graphics, GUI callbacks, 
%   sub-functions, parameter passing, and persistent variables.
%
%      By: Maj Kevin Owens / 30 Apr 2014
%
%  INPUTS: name.obj - text file of vertices defining a polygon
%          name.ops - text file of transform IDs
%
% OUTPUTS: same as inputs
%----------------------------------------------------------------------


%------------------------- Primary Function ---------------------------
% DESCRIPTION: Initializes and launches GUI
%----------------------------------------------------------------------
function PolyTransGUI()

    % Prep GUI
    clc();
    hobject = Create_GUI_components();

    % Define/display default polygon
    G = guidata( hobject );
    G.Poly.Name = 'Square';  
    G.Poly.M = [ -50 50 50 -50; -50 -50 50 50]; % row 1:x, row 2:y
    G.Poly.M(3,:)=ones(1,size(G.Poly.M,2));     % row 3:for transforms    
    G.TransOps = [];     % history of transform operations
    G.OrigPoly = G.Poly; % state before applying transforms
    set(G.GUI_figure, 'Name', G.Poly.Name);
    guidata( hobject, G );
    DrawPoly(G.Poly.M(1:2,:));

end % Pex3_k0


%----------------------------------------------------------------------
% USAGE: NewPoly(hobject,~)
%
% DESCRIPTION: Clears current polygon and defines new one from mouse clicks.
%
% INPUTS:   hobject - contains G.Poly struct
% 
% OUTPUTS:  New polygon in G.Poly
%----------------------------------------------------------------------
function NewPoly(hobject,~)

    % Clear figure
    G = guidata(hobject);
    cla(G.axesMain);
    set(G.GUI_figure, 'Name', 'Record new polygon (press Enter to finish)...');

    % Redefine polygon
    G.Poly.M = ginput';
    G.Poly.M(3,:)=ones(1,size(G.Poly.M,2)); % need a row of 1's for transforms
    G.Poly.Name = '';
    G.Poly.TransOps = [];
    G.OrigPoly = G.Poly;

    % Update figure
    set(G.GUI_figure, 'Name', 'New Polygon');
    guidata(hobject, G);
    DrawPoly(G.Poly.M(1:2,:));
    
end


%----------------------------------------------------------------------
% USAGE: DrawPoly(Vertices)
%
% DESCRIPTION: Draws the specified polygon in the current axes.
%
% INPUTS:   Vertices - (2,:) matrix of x- and y-value pairs for polygon
%           vertices.  (1,:) = x values; (2:1) = y values.  Can be empty.
% 
% OUTPUTS:  A blue filled polygon in the current axes.
%----------------------------------------------------------------------
function DrawPoly(Vertices)

    if ~ isempty(Vertices)
        fill(Vertices(1,:),Vertices(2,:),'b');
    end
    Extent = 500; 
    %      = max(max(abs(Vertices))) * 1.5; % dynamically scale extent based
                                            % on size of polygon
    axis([-Extent Extent -Extent Extent]);

end % DrawPoly


%----------------------------------------------------------------------
% USAGE: LoadPoly(hobject, ~))
%
% DESCRIPTION: Loads & draws a polygon object from user-specified file.
%
% INPUTS:  hobject - contains G.Poly struct
% 
% OUTPUTS: Draws polygon loaded from file.
%----------------------------------------------------------------------
function LoadPoly(hobject, ~)
    
    [FileName,PathName,FilterIndex] = uigetfile('*.obj','Open Object File');
    if ~ FilterIndex == 0
        FID = fopen(sprintf('%s%s', PathName, FileName), 'rt');
        G = guidata(hobject);
        G.Poly.Name = fgetl(FID); % first line is object name (can include spaces)
        Coords = textscan(FID, '%f %f'); % remaining lines are x-y coord pairs
        G.Poly.M = [Coords{1} Coords{2}]'; % convert cell array -> 2-row matrix
        G.Poly.M(3,:)=ones(1,size(G.Poly,2)); % 3rd row of ones for transforms
        fclose(FID);
        G.OrigPoly = G.Poly; % save for reset option
        
        DrawPoly(G.Poly.M(1:2,:));
        set(G.GUI_figure, 'Name', G.Poly.Name); % update window title
        guidata(hobject, G); % save modified poly
    end

end % LoadPoly


%----------------------------------------------------------------------
% USAGE: SavePoly(hobject, ~))
%
% DESCRIPTION: Saves the current polygon object to a user-specified file.
%
% INPUTS:  hobject - contains G.Poly struct
% 
% OUTPUTS: Text file with ".obj" extension, structured as follows:
%          - Line 1: object name
%          - Line n: x,y coord pairs, tab-delimited
%----------------------------------------------------------------------
function SavePoly(hobject, ~)

    % Get name of polygon from user
    G = guidata(hobject);
    Name = inputdlg( 'Name:', 'Save Polygon', 1, { G.Poly.Name } );
        % Cell array of return strings, but there is only 1 return string.
        % If user hit Cancel, Name is empty.
        % If user submitted empty string, Name contains an empty string.
        
    if ~ (isempty(Name) || isempty(Name{1})) % if entered non-empty string

        % Name polygon
        G.Poly.Name = Name{1};
        set(G.GUI_figure, 'Name', G.Poly.Name); % update window title
        guidata(hobject, G);

        % Save polygon
        [FileName,PathName,FilterIndex] = uiputfile('*.obj', ...
            'Save Polygon Object');
        if ~ FilterIndex == 0 % if didn't cancel save dialog
            fileID = fopen(sprintf('%s%s', PathName, FileName),'wt');
            fprintf(fileID,'%s\n', Name{1}); % save polygon name
            if ~ isempty(G.Poly.M) 
                fprintf(fileID,'%d\t%d\n', G.Poly.M(1:2,:)); 
                    % save vertices in column order
            end
            fclose(fileID);
        end
    end

end % SavePoly

%----------------------------------------------------------------------
% USAGE: DoTransOp( hobject, eventdata, Op )
%
% DESCRIPTION: Performs specified transform operation.
%
% INPUTS:   hobject - contains G.Poly.M, a (2,:) matrix of x- and y-value 
%               pairs for poly vertices
%           eventdata - used to flag when to add operation to the history
%               empty (when used as callback): add to history
%               non-empty (when used by DoTransOps): do not add to history
%           Op - the operation # to perform
%               2:up, 3:down, 4:left, 5:right
%               6:cw, 7:ccw, 8:scale up, 9:scale down
%               (note 1 is not used to maintain backward compatibility with
%               the files used by the non-GUI text menu version of this 
%               program, where 1 was the option for loading from file)
% 
% OUTPUTS:  Transformed and redrawn polygon.
%----------------------------------------------------------------------
function DoTransOp( hobject, eventdata, Op )

    persistent TMX; % transformation matrices mapped to menu options
    if isempty(TMX)
        TMX = { [], ...                                 % skip "option 1"
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

    G = guidata(hobject);
    if isempty(eventdata)
        G.TransOps(end+1) = Op; % save operation
    end
    G.Poly.M = MXmult(TMX{Op}, G.Poly.M); % do trans op
    DrawPoly(G.Poly.M(1:2,:));
    guidata(hobject, G);

end % DoTransOp


%----------------------------------------------------------------------
% USAGE: DoTransOps(hobject, ~))
%
% DESCRIPTION: Replays history of transformation operations from
%              polygon's starting configuration.
%
% INPUTS:  hobject G.Poly
%                  G.TransOps
% 
% OUTPUTS: Draws series of transforms as given in G.TransOps.
%----------------------------------------------------------------------
function DoTransOps( hobject, ~ )

    % Restore original polygon
    G = guidata(hobject);
    G.Poly = G.OrigPoly;
    DrawPoly(G.Poly.M(1:2,:));
    guidata(hobject, G); % must precede calls to DoTransOp
    
    % Playback history of transposition operations
    for i = 1:length(G.TransOps)
        pause(0.03);
        DoTransOp(hobject, 'replay', G.TransOps(i));
    end

end % DoTransOps


%----------------------------------------------------------------------
% USAGE: LoadTransOps(hobject, ~))
%
% DESCRIPTION: Loads and runs history of transformation operations from 
%              user-specified file.
%
% INPUTS:  Text file of transformation operation IDs, with delimiter
%          inferred from formatting of the file (newline, tab, comma, etc.)
% 
% OUTPUTS: Transforms into G.TransOps from file; playback of transforms.
%----------------------------------------------------------------------
function LoadTransOps(hobject, ~)

    [FileName,PathName,FilterIndex] = uigetfile('*.ops', ...
        'Open Operations File');
    if ~ FilterIndex == 0 % if didn't hit cancel
        G = guidata(hobject);
        G.TransOps = dlmread(sprintf('%s%s', PathName, FileName));
        guidata(hobject, G);
        DoTransOps(hobject, []);
    end

end % LoadTransOps


%----------------------------------------------------------------------
% USAGE: SaveTransOps(hobject, ~))
%
% DESCRIPTION: Saves history of transformation operation IDs to user-
%              specified file.
%
% INPUTS:  hobject G.TransOps
% 
% OUTPUTS: Text file of transform IDs, delimited by newlines.
%----------------------------------------------------------------------
function SaveTransOps(hobject, ~)

    [FileName,PathName,FilterIndex] = uiputfile('*.ops', ...
        'Save Operations File');
    if ~ FilterIndex == 0 % if didn't hit cancel
        G = guidata(hobject);
        dlmwrite(sprintf('%s%s', PathName, FileName), G.TransOps, '\n');
    end

end % SaveTransOps


%----------------------------------------------------------------------
% USAGE: ResetPoly(hobject, ~))
%
% DESCRIPTION: Resets poly to initial state and clears transform history.
%
% INPUTS:  hobject G.Poly
%                  G.TransOps
% 
% OUTPUTS: Redraws poly in its original configuration.
%----------------------------------------------------------------------
function ResetPoly(hobject, ~)

    G = guidata(hobject);
    G.Poly = G.OrigPoly;
    G.TransOps = [];
    guidata(hobject, G);
    
    DrawPoly(G.Poly.M(1:2,:));

end % ResetPoly


%----------------------------------------------------------------------
% USAGE: Exit(hobject, ~))
%
% DESCRIPTION: Exits the program, closing the figure window.  Does not
%              check for unsaved polygon.
%
% INPUTS:  hobject G.GUI_figure
% 
% OUTPUTS: None.
%----------------------------------------------------------------------
function Exit(hobject, ~)

    G = guidata(hobject);
    close(G.GUI_figure);

end % Exit


%----------------------------------------------------------------------
% USAGE: Result = MXmult(A, B)
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

    Result = zeros(size(A,1), size(B,2)); % an A-rows by B-cols matrix
    for Ar = 1:size(A,1) % for each row in A
        for Bc = 1:size(B,2) % for each col in B
            
            % sum element-wise product of row in A and col in B
            for Ac = 1:size(A,2) % for each col in A-row
                Result(Ar,Bc) = Result(Ar,Bc) + ...
                    A(Ar,Ac) * B(Ac,Bc);
            end
            
        end
    end
    
    % A(r, c)      Illustration of iteration over the first row in A,
    %    B(r, c)   where A is a 3x2 and B is a 2x4.
    %   1  1  1    
    %   1  2  1    Iteration occurs
    %   1  1  2    first over A(r,:) (first column in diagram)
    %   1  2  2     then over B(:,c) (third column in diagram)
    %   1  1  3     then over A(:,c) (secnd column in diagram, same as B(r,:))
    %   1  2  3
    %   1  1  4
    %   1  2  4

end % MXmult

%---------------------- Create_GUI_components() -----------------------
function FigureHandle = Create_GUI_components()
% NOTE: If GUIbuilder is used to modify this program,
% the Create_GUI_components function will be re-created.
% Therefore, the only modifications you should make to this
% function are:
%    - add or delete property/value pairs to components
%    - modify an individual property value of a component.
% If you need to calculate the value of a component's
% property, perform the calculations in a separate function.
%
G.GUI_figure = figure( ...
   'Tag',                   'GUI_figure', ...
   'Name',                  'GUIbuilder - DesignWindow', ...
   'NumberTitle',           'off', ...
   'MenuBar',               'none', ...
   'ToolBar',               'none', ...
   'DockControls',          'off', ...
   'Units',                 'normalized', ...
   'Position',              [0.45000 0.33500 0.50000 0.50000], ...
   'Color',                 [1.00000 1.00000 1.00000], ...
   'WindowButtonDownFcn',   [], ...
   'WindowButtonMotionFcn', [], ...
   'WindowButtonUpFcn',     [], ...
   'WindowKeyPressFcn',     [], ...
   'WindowKeyReleaseFcn',   [], ...
   'WindowScrollWheelFcn',  []);

G.axesMain = axes( ...
   'Tag',        'axesMain', ...
   'Parent',     G.GUI_figure, ...
   'Units',      'normalized', ...
   'Position',   [0.40000 0.05750 0.57969 0.91750], ...
   'XLim',       [0.00000 1.00000], ...
   'Xtick',      [0.00000 1.00000], ...
   'YLim',       [0.00000 1.00000], ...
   'Ytick',      [0.00000 1.00000], ...
   'Color',      [0.75000 0.75000 0.75000], ...
   'XTickLabel', ['0'; '1'], ...
   'YTickLabel', ['0'; '1']);

G.txtPolyOps = uicontrol( ...
   'Tag',             'txtPolyOps', ...
   'Parent',          G.GUI_figure, ...
   'Units',           'normalized', ...
   'Position',        [0.04250 0.91500 0.27969 0.05750], ...
   'Style',           'text', ...
   'String',          'Polygon Operations', ...
   'FontSize',        12.00000, ...
   'FontWeight',      'bold', ...
   'BackgroundColor', [1.00000 1.00000 1.00000]);

G.btnNewPoly = uicontrol( ...
   'Tag',      'btnNewPoly', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.02187 0.83250 0.15469 0.07500], ...
   'Callback', @NewPoly, ...
   'Style',    'pushbutton', ...
   'String',   'New');

G.btnResetPoly = uicontrol( ...
   'Tag',      'btnResetPoly', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.18906 0.83250 0.15469 0.07500], ...
   'Callback', @ResetPoly, ...
   'Style',    'pushbutton', ...
   'String',   'Reset');

G.btnLoadPoly = uicontrol( ...
   'Tag',      'btnLoadPoly', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.02219 0.73750 0.15469 0.07500], ...
   'Callback', @LoadPoly, ...
   'Style',    'pushbutton', ...
   'String',   'Load');

G.btnSavePoly = uicontrol( ...
   'Tag',      'btnSavePoly', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.18937 0.73750 0.15469 0.07500], ...
   'Callback', @SavePoly, ...
   'Style',    'pushbutton', ...
   'String',   'Save');

G.txtTransOps = uicontrol( ...
   'Tag',             'txtTransOps', ...
   'Parent',          G.GUI_figure, ...
   'Units',           'normalized', ...
   'Position',        [0.04125 0.62284 0.27969 0.05717], ...
   'Style',           'text', ...
   'String',          'Transform Operations', ...
   'FontSize',        12.00000, ...
   'FontWeight',      'bold', ...
   'BackgroundColor', [1.00000 1.00000 1.00000]);

G.btnLoadOps = uicontrol( ...
   'Tag',      'btnLoadOps', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.02250 0.15500 0.09844 0.07500], ...
   'Callback', @LoadTransOps, ...
   'Style',    'pushbutton', ...
   'String',   'Load');

G.btnSaveOps = uicontrol( ...
   'Tag',      'btnSaveOps', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.13281 0.15500 0.09844 0.07500], ...
   'Callback', @SaveTransOps, ...
   'Style',    'pushbutton', ...
   'String',   'Save');

G.btnRunOps = uicontrol( ...
   'Tag',      'btnRunOps', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.24312 0.15500 0.09844 0.07500], ...
   'Callback', @DoTransOps, ...
   'Style',    'pushbutton', ...
   'String',   'Run');

G.btnExit = uicontrol( ...
   'Tag',             'btnExit', ...
   'Parent',          G.GUI_figure, ...
   'Units',           'normalized', ...
   'Position',        [0.10563 0.02500 0.15469 0.07500], ...
   'Callback',        @Exit, ...
   'Style',           'pushbutton', ...
   'String',          'Exit', ...
   'FontWeight',      'bold', ...
   'ForegroundColor', [1.00000 0.00000 0.00000]);

G.btnTransUp = uicontrol( ...
   'Tag',      'btnTransUp', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.13469 0.53830 0.09844 0.07457], ...
   'Callback', {@DoTransOp, 2.00000 }, ...
   'Style',    'pushbutton', ...
   'String',   'Up');

G.btnTransDown = uicontrol( ...
   'Tag',      'btnTransDown', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.13500 0.44881 0.09844 0.07457], ...
   'Callback', {@DoTransOp, 3.00000 }, ...
   'Style',    'pushbutton', ...
   'String',   'Down');

G.btnTransLeft = uicontrol( ...
   'Tag',      'btnTransLeft', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.02500 0.49852 0.09844 0.07457], ...
   'Callback', {@DoTransOp, 4.00000 }, ...
   'Style',    'pushbutton', ...
   'String',   'Left');

G.btnTransRight = uicontrol( ...
   'Tag',      'btnTransRight', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.24469 0.50101 0.09844 0.07457], ...
   'Callback', {@DoTransOp, 5.00000 }, ...
   'Style',    'pushbutton', ...
   'String',   'Right');

G.btnTransCW = uicontrol( ...
   'Tag',      'btnTransCW', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.02375 0.30960 0.09844 0.07457], ...
   'Callback', {@DoTransOp, 6.00000 }, ...
   'Style',    'pushbutton', ...
   'String',   'CW');

G.btnTransCCW = uicontrol( ...
   'Tag',      'btnTransCCW', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.24344 0.31209 0.09844 0.07457], ...
   'Callback', {@DoTransOp, 7.00000 }, ...
   'Style',    'pushbutton', ...
   'String',   'CCW');

G.btnTransScaleUp = uicontrol( ...
   'Tag',      'btnTransScaleUp', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.13344 0.34938 0.09844 0.07457], ...
   'Callback', {@DoTransOp, 8.00000 }, ...
   'Style',    'pushbutton', ...
   'String',   'Larger');

G.btnTransScaleDown = uicontrol( ...
   'Tag',      'btnTransScaleDown', ...
   'Parent',   G.GUI_figure, ...
   'Units',    'normalized', ...
   'Position', [0.13375 0.25989 0.09844 0.07457], ...
   'Callback', {@DoTransOp, 9.00000 }, ...
   'Style',    'pushbutton', ...
   'String',   'Smaller');

FigureHandle = G.GUI_figure;
guidata( FigureHandle, G );

end % Create_GUI_components function

