%%%-------------------------------------------------------------------
%%% @author Mikael Bylund <mikael.bylund@gmail.com>
%%% @copyright (C) 2012, Mikael Bylund
%%% @doc
%%%
%%% @end
%%% Created : 4 July 2012 by Mikael Bylund <mikael.bylund@gmail.com>
%%%-------------------------------------------------------------------
-module(eGuiFunctions).
-author("mikael.bylund@gmail.com").

-include("eTodo.hrl").

-include_lib("wx/include/wx.hrl").

%% API
-export([addTodo/4,
         appendToPage/2,
         appendToReminders/2,
         checkStatus/1,
         checkUndoStatus/1,
         clearAndInitiate/2,
         clearStatusBar/1,
         doLogout/2,
         findSelected/1,
         focusAndSelect/1,
         focusAndSelect/2,
         generateWorkLog/1,
         getCheckedItems/1,
         getPortrait/1,
         getTaskList/1,
         getTodoList/2,
         getTodoLists/1,
         makeETodo/3,
         obj/2,
         pos/2,
         saveColumnSizes/1,
         setColumnWidth/4,
         setColor/2,
         setDoneTimeStamp/3,
         setOwner/3,
         setPeerStatusIfNeeded/1,
         setPortrait/2,
         setSelection/1,
         setSelection/2,
         setSelection/4,
         setTaskLists/2,
         showBookmarkMenu/2,
         showMenu/4,
         updateGui/3,
         updateGui/4,
         updateTodo/4,
         updateTodoInDB/2,
         updateTodoWindow/1,
         updateValue/4,
         useFilter/3,
         userStatusAvailable/1,
         userStatusAway/1,
         userStatusBusy/1,
         userStatusOffline/1,
         userStatusUpdate/1,
         wxDate/1,
         xrcId/1]).

-import(eTodoUtils, [col/2,
                     dateTime/0,
                     default/2,
                     doneTime/2,
                     getRootDir/0,
                     makeStr/1,
                     toStr/1]).

-import(eRows, [findIndex/2,
                getETodoAtIndex/2,
                insertRow/3,
                updateRows/2]).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
addTodo(TodoList, ETodo, Row, State) ->
    wxListCtrl:insertItem(TodoList, Row, ""),
    Rows2 = insertRow(ETodo, Row, State#guiState.rows),
    updateTodo(TodoList, ETodo, Row, State#guiState{rows = Rows2}).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
updateTodo(List, ETodo, Row, State) ->
    setRowInfo(List, ETodo, Row),
    Rows2 = updateRows(ETodo, State#guiState.rows),
    State#guiState{rows = Rows2}.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
appendToPage(MsgObj, {Html, _HtmlCSS}) ->
    wxHtmlWindow:appendToPage(MsgObj, Html),
    setScrollBar(MsgObj).

appendToReminders(MsgObj, {Html, _HtmlCSS}) ->
    wxHtmlWindow:appendToPage(MsgObj, Html),
    setScrollBar(MsgObj).

setScrollBar(MsgObj) ->
    Range = wxHtmlWindow:getScrollRange(MsgObj, ?wxVERTICAL),
    wxHtmlWindow:scroll(MsgObj, 0, Range).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
doLogout(_User, State = #guiState{loggedIn = false}) ->
    State;
doLogout(User, State) ->
    StatusBar = obj("mainStatusBar", State),
    wxStatusBar:setStatusText(StatusBar, User,           [{number, 0}]),
    wxStatusBar:setStatusText(StatusBar, ?sbNotLoggedIn, [{number, 1}]),
    userStatusOffline(State),

    ePeerEM:loggedOut(User),
    eWeb:stop(),
    checkStatus(State#guiState{loggedIn = false}).


%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
getCheckedItems(Obj) ->
    Count = wxCheckListBox:getCount(Obj),
    getCheckedItems(Obj, Count - 1, []).

getCheckedItems(_Obj, -1, Items) ->
    lists:sort(Items);
getCheckedItems(Obj, Index, Items) ->
    case wxCheckListBox:isChecked(Obj, Index) of
        true ->
            Item = wxCheckListBox:getString(Obj, Index),
            case catch list_to_integer(Item) of
                {'EXIT', _Reason} ->
                    getCheckedItems(Obj, Index - 1, [Item|Items]);
                IntValue ->
                    getCheckedItems(Obj, Index - 1, [IntValue|Items])
            end;
        false ->
            getCheckedItems(Obj, Index - 1, Items)
    end.

%%======================================================================
%% Get configured task list
%%======================================================================
getTaskList(State = #guiState{drillDown = []}) ->
    Obj   = obj("taskListChoice", State),
    Index = wxChoice:getSelection(Obj),
    wxChoice:getString(Obj, Index);
getTaskList(#guiState{drillDown = [Uid|_Rest]}) ->
    Uid.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
getTodoList(_List, State) -> obj("mainTaskList", State).

%%======================================================================
%% Function : obj(Name, State) -> This
%% Purpose  : Get object reference for object Name...
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
getTodoLists(User) ->
    UserCfg = eTodoDB:readUserCfg(User),
    lists:sort(default(UserCfg#userCfg.lists, [?defTaskList])).

%%======================================================================
%% Function : obj(Name, State) -> This
%% Purpose  : Get object reference for object Name...
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
focusAndSelect(State) ->
    focusAndSelect(0, State).

focusAndSelect(Index, State = #guiState{user    = User,
                                        columns = Columns}) ->
    TaskList = getTaskList(State),
    TodoList = getTodoList(TaskList, State),
    wxListCtrl:setFocus(TodoList),
    case wxListCtrl:getItemCount(TodoList) of
        Row when Row > Index ->
            wxListCtrl:ensureVisible(TodoList, Index),
            wxListCtrl:setItemState(TodoList, Index,
                                    ?wxLIST_STATE_SELECTED,
                                    ?wxLIST_STATE_SELECTED);
        Row when (Row == Index) and (Index > 0) ->
            wxListCtrl:ensureVisible(TodoList, Index - 1),
            wxListCtrl:setItemState(TodoList, Index - 1,
                                    ?wxLIST_STATE_SELECTED,
                                    ?wxLIST_STATE_SELECTED);
        Row when Row > 0 ->
            wxListCtrl:ensureVisible(TodoList, 0),
            wxListCtrl:setItemState(TodoList, 0,
                                    ?wxLIST_STATE_SELECTED,
                                    ?wxLIST_STATE_SELECTED);
        _Row ->
            updateGui(makeETodo(#todo{}, User, Columns), 0, State)
    end,
    State.
%%======================================================================
%% Function : obj(Name, State) -> This
%% Purpose  : Get object reference for object Name...
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
obj(Name, #guiState{frame = Frame}) ->
    obj(Name, Frame);
obj(Name, Frame) ->
    %% Cache for faster access.
    case get({wxObj, Name}) of
        undefined ->
            Obj = wxXmlResource:xrcctrl(Frame, Name, type(Name)),
            put({wxObj, Name}, Obj),
            Obj;
        Obj ->
            Obj
    end.

type("splitter" ++ _)     -> wxSplitterWindow;
type("messagePanel")      -> wxPanel;
type("userStatusPanel")   -> wxPanel;
type("mainNotebook")      -> wxNotebook;
type("mainTaskList")      -> wxListCtrl;
type("msgTextWin")        -> wxHtmlWindow;
type("remTextWin")        -> wxHtmlWindow;
type("workLogReport")     -> wxHtmlWindow;
type("userStatusMsg")     -> wxTextCtrl;
type("msgTextCtrl")       -> wxTextCtrl;
type("descriptionArea")   -> wxTextCtrl;
type("commentArea")       -> wxTextCtrl;
type("descriptionArea1")  -> wxTextCtrl;
type("commentArea1")      -> wxTextCtrl;
type("sharedWithText1")   -> wxTextCtrl;
type("descriptionArea2")  -> wxTextCtrl;
type("commentArea2")      -> wxTextCtrl;
type("sharedWithText2")   -> wxTextCtrl;
type("dueDatePicker")     -> wxDatePickerCtrl;
type("dueDatePicker1")    -> wxDatePickerCtrl;
type("dueDatePicker2")    -> wxDatePickerCtrl;
type("startDate")         -> wxDatePickerCtrl;
type("endDate")           -> wxDatePickerCtrl;
type("workLogStartDate")  -> wxDatePickerCtrl;
type("userStatusChoice")  -> wxChoice;
type("taskListChoice")    -> wxChoice;
type("statusChoice")      -> wxChoice;
type("priorityChoice")    -> wxChoice;
type("statusChoice1")     -> wxChoice;
type("priorityChoice1")   -> wxChoice;
type("statusChoice2")     -> wxChoice;
type("priorityChoice2")   -> wxChoice;
type("ownerChoice1")      -> wxChoice;
type("ownerChoice2")      -> wxChoice;
type("ownerChoice")       -> wxChoice;
type("useStartDate")      -> wxCheckBox;
type("useEndDate")        -> wxCheckBox;
type("checkBoxUseFilter") -> wxCheckBox;
type("progressInfo")      -> wxSpinCtrl;
type("progressInfo1")     -> wxSpinCtrl;
type("progressInfo2")     -> wxSpinCtrl;
type("mainStatusBar")     -> wxStatusBar;
type("eTodoToolbar")      -> wxToolBar;
type("userCheckBox")      -> wxCheckListBox;
type("listCheckBox")      -> wxCheckListBox;
type("setReminderButton") -> wxBitmapButton;
type("shareButton")       -> wxBitmapButton;
type("shareButton2")      -> wxBitmapButton;
type("taskEditPanel")     -> wxPanel;
type("mainPanel")         -> wxPanel;
type("infoIcon")          -> wxStaticBitmap;
type("userAvailableIcon") -> wxStaticBitmap;
type("userBusyIcon")      -> wxStaticBitmap;
type("userAwayIcon")      -> wxStaticBitmap;
type("userOfflineIcon")   -> wxStaticBitmap;
type("peerAvailableIcon") -> wxStaticBitmap;
type("peerBusyIcon")      -> wxStaticBitmap;
type("peerAwayIcon")      -> wxStaticBitmap;
type("portraitPeerIcon")  -> wxStaticBitmap;
type("addedToLists")      -> wxStaticText;
type("sharedWithText")    -> wxStaticText;
type("peerStatusMsg")     -> wxStaticText;
type("searchText")        -> wxComboBox;
type(_)                   -> wxRadioBox.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
setDoneTimeStamp(ETodo = #etodo{statusDB = Status}, Index,
                 State = #guiState{user     = User}) ->
    OldDoneTime = ETodo#etodo.doneTimeDB,
    DoneTime    = doneTime(OldDoneTime, Status),
    ETodo2      = ETodo#etodo{doneTimeDB = DoneTime,
                              doneTime   = toStr(DoneTime)},

    updateTodoInDB(User, ETodo2),

    TaskList = getTaskList(State),
    TodoList = getTodoList(TaskList, State),
    State2   = updateTodo(TodoList, ETodo2, Index, State),
    eLog:log(debug, ?MODULE, saveGuiSettings, [ETodo2],
             "Active todo updated.", ?LINE),
    State2#guiState{activeTodo = {ETodo2, Index}}.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
setTaskLists(Lists, State = #guiState{user = User}) ->
    Obj2 = obj("taskListChoice", State),
    TodoLists = getTodoLists(User),
    eTodoDB:moveTodosToTaskList(User, ?defTaskList, TodoLists -- Lists),
    UserCfg = eTodoDB:readUserCfg(User),
    eTodoDB:saveUserCfg(UserCfg#userCfg{lists = Lists}),
    TaskList = getTaskList(State),
    wxChoice:clear(Obj2),
    Default =
        case TaskList of
            Uid when is_integer(Uid) ->
                SubTaskText = ?subTaskList ++ toStr(Uid),
                wxChoice:append(Obj2, SubTaskText),
                SubTaskText;
            Chosen ->
                Chosen
        end,
    wxChoice:append(Obj2, ?defInbox),
    [wxChoice:append(Obj2, List) || List <- Lists],
    setSelection(Obj2, Default).

setSelection(Obj) ->
    setSelection(Obj, ?defTaskList).

setSelection(Obj, Selection) ->
    Count = wxChoice:getCount(Obj),
    setSelection(Obj, Count - 1, Selection).

setSelection(Obj, 0, _Selection) ->
    wxChoice:setSelection(Obj, 0);
setSelection(Obj, Index, Selection) ->
    case wxChoice:getString(Obj, Index) of
        Selection ->
            wxChoice:setSelection(Obj, Index);
        ?descNA when Selection == "" ->
            wxChoice:setSelection(Obj, Index);
        _ ->
            setSelection(Obj, Index - 1, Selection)
    end.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
updateGui(undefined, _Index, State = #guiState{user    = User,
                                               columns = Columns}) ->
    updateGui(makeETodo(#todo{}, User, Columns), 0, State);
updateGui(ETodo, Index, State) ->
    updateValue("descriptionArea",   State, ETodo#etodo.description),
    updateValue("sharedWithText",    State, ETodo#etodo.sharedWith),
    updateValue("addedToLists",      State, ETodo#etodo.lists),
    updateValue("commentArea",       State, ETodo#etodo.comment),
    doSetSelection("statusChoice",   State, ETodo#etodo.status),
    doSetSelection("priorityChoice", State, ETodo#etodo.priority),
    DueDateObj  = obj("dueDatePicker", State),
    ProgressObj = obj("progressInfo",  State),
    OwnerObj    = obj("ownerChoice",   State),
    wxDatePickerCtrl:setValue(DueDateObj, wxDate(ETodo#etodo.dueTimeDB)),
    setOwner(OwnerObj, State#guiState.user, ETodo#etodo.owner),


    case ETodo#etodo.statusDB of
        done ->
            wxSpinCtrl:setValue(ProgressObj, 100);
        _ ->
            wxSpinCtrl:setValue(ProgressObj, default(ETodo#etodo.progress, 0))
    end,
    checkStatus(setDoneTimeStamp(ETodo, Index, State)).

updateValue(_Name, _State, Value, Value) ->
    ok;
updateValue(Name, State, Value, _OldValue) ->
    updateValue(Name, State, Value).

updateValue(Name, State = #guiState{frame = Frame}, Value) ->
    Obj = obj(Name, State),
    case {type(Name), Name} of
        {wxTextCtrl, Name} when
              (Name == "descriptionArea") or
              (Name == "commentArea")     ->
            %% Do not generate update event when showing new eTodo, only
            %% when the user edits the field.
            wxFrame:disconnect(Frame, command_text_updated, [{id, xrcId(Name)}]),
            wxTextCtrl:setValue(Obj, Value),
            wxFrame:connect(Frame, command_text_updated, [{id, xrcId(Name)}]);
        {wxTextCtrl, Name} ->
            wxTextCtrl:setValue(Obj, Value);
        {wxStaticText, _} ->
            wxStaticText:setLabel(Obj, Value)
    end.

setSelection(_Name, _State, Value, Value) ->
    ok;
setSelection(Name, State, Value, _OldValue) ->
    doSetSelection(Name, State, Value).

doSetSelection(Name, State, Value) ->
    Obj = obj(Name, State),
    setSelection(Obj, Value).

setOwner(OwnerObj, User, Owner) ->
    Peers    = eTodoDB:getUsers(),
    #userCfg{ownerCfg = OwnerCfg} = eTodoDB:readUserCfg(User),
    PeerList = [User | lists:delete(User, Peers)] ++ default(OwnerCfg, []),
    wxChoice:clear(OwnerObj),
    [wxChoice:append(OwnerObj, Peer) || Peer <- lists:sort(PeerList)],
    setSelection(OwnerObj, Owner).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
updateGui(#etodo{description = OldDesc,
                 sharedWith  = OldShare,
                 lists       = OldLists,
                 comment     = OldComment,
                 status      = OldStatus,
                 priority    = OldPriority,
                 dueTimeDB   = OldDueTime,
                 owner       = OldOwner},
          ETodo = #etodo{description = Desc,
                         sharedWith  = Share,
                         lists       = Lists,
                         comment     = Comment,
                         status      = Status,
                         priority    = Priority,
                         dueTimeDB   = DueTime,
                         owner       = Owner,
                         progress    = Progress}, Index, State) ->

    updateValue("descriptionArea", State, Desc,     OldDesc),
    updateValue("sharedWithText",  State, Share,    OldShare),
    updateValue("addedToLists",    State, Lists,    OldLists),
    updateValue("commentArea",     State, Comment,  OldComment),
    setSelection("statusChoice",   State, Status,   OldStatus),
    setSelection("priorityChoice", State, Priority, OldPriority),
    DueDateObj  = obj("dueDatePicker", State),
    if DueTime =/= OldDueTime ->
            wxDatePickerCtrl:setValue(DueDateObj, wxDate(DueTime));
       true ->
            ok
    end,
    if Owner =/= OldOwner ->
            OwnerObj = obj("ownerChoice",   State),
            sendUpdate(State#guiState.user, Owner, ETodo),
            setOwner(OwnerObj, State#guiState.user, Owner);
       true ->
            ok
    end,
    ProgressObj = obj("progressInfo",  State),

    case ETodo#etodo.statusDB of
        done ->
            wxSpinCtrl:setValue(ProgressObj, 100);
        _ ->
            wxSpinCtrl:setValue(ProgressObj, default(Progress, 0))
    end,
    setDoneTimeStamp(ETodo, Index, State).

setRowInfo(List, #etodo{priority       = Priority,
                        priorityCol    = PriorityCol,
                        status         = Status,
                        statusCol      = StatusCol,
                        owner          = Owner,
                        ownerCol       = OwnerCol,
                        doneTime       = DoneTime,
                        doneTimeCol    = DoneTimeCol,
                        dueTime        = DueTime,
                        dueTimeCol     = DueTimeCol,
                        createTime     = CreateTime,
                        createTimeCol  = CreateTimeCol,
                        comment        = Comment,
                        commentCol     = CommentCol,
                        description    = Desc,
                        descriptionCol = DescCol,
                        sharedWith     = SharedWith,
                        sharedWithCol  = SharedWithCol,
                        uid            = Uid,
                        uidCol         = UidCol,
                        hasSubTodo     = HasSubTodo}, Row) ->

    wxListCtrl:setItem(List, Row, UidCol,        Uid),
    wxListCtrl:setItem(List, Row, StatusCol,     Status),
    wxListCtrl:setItem(List, Row, OwnerCol,      Owner),
    wxListCtrl:setItem(List, Row, PriorityCol,   Priority),
    wxListCtrl:setItem(List, Row, DueTimeCol,    DueTime),
    wxListCtrl:setItem(List, Row, DescCol,       colFormat(Desc)),
    wxListCtrl:setItem(List, Row, CommentCol,    colFormat(Comment)),
    wxListCtrl:setItem(List, Row, SharedWithCol, SharedWith),
    wxListCtrl:setItem(List, Row, CreateTimeCol, CreateTime),
    wxListCtrl:setItem(List, Row, DoneTimeCol,   DoneTime),

    case HasSubTodo of
        false ->
            case Status of
                ?descDone ->
                    wxListCtrl:setItemImage(List, Row, 2);
                _ ->
                    wxListCtrl:setItemImage(List, Row, 0)
            end;
        true ->
            wxListCtrl:setItemImage(List, Row, 1)
    end,
    setColor(List, Row).

setColor(List, Row) ->
    case Row rem 2 of
        0 ->
            Color = {230, 230, 230, 255},
            wxListCtrl:setItemBackgroundColour(List, Row, Color);
        _ ->
            Color = {255, 255, 255, 255},
            wxListCtrl:setItemBackgroundColour(List, Row, Color)
    end.

colFormat(ColumnText) ->
    colFormat(ColumnText, 160, []).

colFormat([], _Num, Text) ->
    lists:reverse(Text);
colFormat(_ColumnText, 0, Text) ->
    lists:reverse("..." ++ Text);
colFormat([13, 10, 13, 10|_Rest], _Num, Text) ->
    lists:reverse(Text);
colFormat([10, 10|_Rest], _Num, Text) ->
    lists:reverse(Text);
colFormat([10|Rest], Num, Text) ->
    colFormat(Rest, Num - 1, [32|Text]);
colFormat([13|Rest], Num, Text) ->
    colFormat(Rest, Num - 1, [32|Text]);
colFormat([Char|Rest], Num, Text) ->
    colFormat(Rest, Num - 1, [Char|Text]).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
updateTodoInDB(_User, #etodo{uidDB = undefined}) ->
    %% This is a constructed task for clearing task window, do not save.
    ok;
updateTodoInDB(User, #etodo{uidDB        = Uid,
                            priorityDB   = Prio,
                            statusDB     = Status,
                            doneTimeDB   = DoneTime,
                            dueTimeDB    = DueTime,
                            createTimeDB = CreateTime,
                            comment      = Comment,
                            description  = Description,
                            progress     = Progress,
                            sharedWithDB = SharedWith,
                            owner        = Owner}) ->
    Todo = #todo{uid         = Uid,
                 priority    = Prio,
                 status      = Status,
                 doneTime    = DoneTime,
                 dueTime     = DueTime,
                 createTime  = CreateTime,
                 comment     = Comment,
                 description = Description,
                 progress    = Progress,
                 sharedWith  = SharedWith,
                 owner       = Owner},
    eTodoDB:updateTodo(User, Todo).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
updateTodoWindow(State = #guiState{searchCfg = Cfg,
                                   user      = User,
                                   filter    = Filter}) ->
    SearchText = wxComboBox:getValue(obj("searchText", State)),
    TaskList   = getTaskList(State),
    TodoList   = getTodoList(TaskList, State),
    TodoLists  = getTodoLists(User),
    setTaskLists(TodoLists, State),

    TaskList3 = case TaskList of
                    ?subTaskList ++ _ ->
                        TaskList2 = State#guiState.drillFromList,
                        setSelection(obj("taskListChoice", State), TaskList2),
                        TaskList2;
                    _ ->
                        TaskList
                end,
    Filter2 = useFilter(TaskList, Filter, State),
    updateColumns(Filter2, State),
    ETodos = eTodoDB:getETodos(User, TaskList3, Filter2, SearchText, Cfg),

    wxListCtrl:freeze(TodoList),
    clearAndInitiate(TodoList, length(ETodos)),
    lists:foldl(fun (ETodo, Acc) ->
                        setRowInfo(TodoList, ETodo, Acc),
                        Acc + 1
                end, 0, ETodos),
    wxListCtrl:thaw(TodoList),
    wxListCtrl:setItemState(TodoList, getActive(State),
                            ?wxLIST_STATE_SELECTED,
                            ?wxLIST_STATE_SELECTED),
    updateInfoIcon(State),
    State#guiState{rows = eRows:replace(ETodos, State#guiState.rows)}.

getActive(#guiState{activeTodo = {_, Index}}) -> Index;
getActive(_)                                  -> 0.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
wxDate({{1970, _, _}, {_, _, _}}) -> undefined;
wxDate({{YY, MM, DD}, {_, _, _}}) -> {YY, MM, DD};
wxDate({YY, MM, DD})              -> {{YY, MM, DD}, {0, 0, 0}};
wxDate(undefined)                 -> {{1970, 0, 0}, {0, 0, 0}}.

%%======================================================================
%% Help functions for menu creation.
%%======================================================================
showBookmarkMenu(Items, State = #guiState{popupBookmMenu = OldMenu,
                                          frame          = Frame}) ->
    removeOldMenu(OldMenu),
    Menu = wxMenu:new(),
    makeMenuItems(Menu, ?bookmarks + 1, Items),
    wxMenu:connect(Menu, command_menu_selected),
    wxWindow:popupMenu(Frame, Menu),
    State#guiState{popupBookmMenu = Menu}.

makeMenuItems(_Menu, _BookmarkItem, []) ->
    ok;
makeMenuItems(Menu, BookmarkItem, [Bookmark | Rest]) ->
    wxMenu:append(Menu, BookmarkItem, Bookmark),
    makeMenuItems(Menu, BookmarkItem + 1, Rest).

showMenu(User, {row, Row}, Frame, State = #guiState{popUpMenu = OldMenu}) ->
    removeOldMenu(OldMenu),
    Menu = createMenu(User, Row, State),
    wxMenu:connect(Menu, command_menu_selected),
    wxWindow:popupMenu(Frame, Menu),
    State#guiState{popUpMenu = Menu, popUpCol  = {row, Row}};
showMenu(User, Column, Frame, State = #guiState{popUpMenu = OldMenu,
                                                filter    = Filter}) ->
    removeOldMenu(OldMenu),
    Menu = createMenu(User, Column, Filter),
    wxMenu:connect(Menu, command_menu_selected),
    wxWindow:popupMenu(Frame, Menu),
    State#guiState{popUpMenu = Menu, popUpCol  = Column}.

removeOldMenu(undefined) -> ok;
removeOldMenu(Menu)      -> wxMenu:destroy(Menu).

createMenu(User, Row, State = #guiState{}) ->
    Menu        = wxMenu:new(),
    %% Create Status submenu
    SubMenu     = wxMenu:new([]),
    SubMenuItem = wxMenuItem:new([{parentMenu, Menu}, {id, ?wxID_ANY},
                                  {text, "Status"}, {subMenu, SubMenu},
                                  {kind, ?wxITEM_NORMAL}]),
    wxMenu:append(Menu, SubMenuItem),
    ID1  = wxMenu:appendRadioItem(SubMenu, ?statusPlanning,   ?descPlanning),
    ID2  = wxMenu:appendRadioItem(SubMenu, ?statusInProgress, ?descInProgress),
    ID3  = wxMenu:appendRadioItem(SubMenu, ?statusDone,       ?descDone),
    ID4  = wxMenu:appendRadioItem(SubMenu, ?statusNone,       ?descNA),

    wxMenu:connect(SubMenu, command_menu_selected),
    setDefault(User, Row, Menu, ID1, ID2, ID3, ID4, State),

    SubMenu2     = wxMenu:new([]),
    SubMenuItem2 = wxMenuItem:new([{parentMenu, Menu}, {id, ?wxID_ANY},
                                   {text, "Lists"}, {subMenu, SubMenu2},
                                   {kind, ?wxITEM_NORMAL}]),
    wxMenu:append(Menu, SubMenuItem2),

    %% Create Lists submenu
    TodoLists = getTodoLists(User),
    Rows      = State#guiState.rows,
    ETodo     = getETodoAtIndex(Row, Rows),
    createSubMenu(SubMenu2, ?lists + 1, ETodo, TodoLists),

    wxMenu:connect(SubMenu2, command_menu_selected),
    Menu;
createMenu(User, Column, Filter) ->
    Menu = wxMenu:new(),
    Def  = wxMenu:appendRadioItem(Menu, ?sortDef, ?descSortDef),
    Asc  = wxMenu:appendRadioItem(Menu, ?sortAsc, ?descSortAsc),
    Dec  = wxMenu:appendRadioItem(Menu, ?sortDec, ?descSortDec),
    setDefault(User, Column, Menu, Def, Asc, Dec),
    addFilter(Menu, Column, Filter),

    %% Add column show configuration
    Columns = [Desc || {_Col, Desc} <- eTodoDB:getColumns(User)],
    SubMenu = wxMenu:new([]),
    SubMenuItem = wxMenuItem:new([{parentMenu, Menu}, {id, ?wxID_ANY},
                                  {text, "Show columns"}, {subMenu, SubMenu},
                                  {kind, ?wxITEM_NORMAL}]),
    createSubMenuForColumns(User, SubMenu, ?showcolumns + 1, Columns),
    wxMenu:append(Menu, SubMenuItem),
    wxMenu:append(Menu, ?sortColumns, "Order columns"),
    wxMenu:connect(SubMenu, command_menu_selected),
    Menu.

createSubMenuForColumns(_User, _SubMenu, _ColItem, []) ->
    ok;
createSubMenuForColumns(User, SubMenu, ColItem, [Col | Rest]) ->
    ID    = wxMenu:appendCheckItem(SubMenu, ColItem, Col),
    Check = checkVisable(User, Col),
    wxMenu:check(SubMenu, wxMenuItem:getId(ID), Check),
    createSubMenuForColumns(User, SubMenu, ColItem + 1, Rest).

checkVisable(User, Col) ->
    ColInternal = eTodoUtils:taskInternal(Col),
    default(eTodoDB:readListCfg(User, ColInternal, visible), true).

createSubMenu(_SubMenu, _ListItem, _ETodo, []) ->
    ok;
createSubMenu(SubMenu, ListItem, ETodo, [List | Rest]) ->
    ID    = wxMenu:appendCheckItem(SubMenu, ListItem, List),
    Check = lists:member(List, ETodo#etodo.listsDB),
    wxMenu:check(SubMenu, wxMenuItem:getId(ID), Check),
    createSubMenu(SubMenu, ListItem + 1, ETodo, Rest).

setDefault(_User, Row, Menu, ID1, ID2, ID3, ID4, State) ->
    ETodo = getETodoAtIndex(Row, State#guiState.rows),
    case ETodo#etodo.statusDB of
        planning   -> wxMenu:check(Menu, wxMenuItem:getId(ID1), true);
        inProgress -> wxMenu:check(Menu, wxMenuItem:getId(ID2), true);
        done       -> wxMenu:check(Menu, wxMenuItem:getId(ID3), true);
        undefined  -> wxMenu:check(Menu, wxMenuItem:getId(ID4), true)
    end.

setDefault(User, Col, Menu, Def, Asc, Dec) ->
    case default(eTodoDB:readListCfg(User, sorted), default) of
        {ascending,  Col} -> wxMenu:check(Menu, wxMenuItem:getId(Asc), true);
        {descending, Col} -> wxMenu:check(Menu, wxMenuItem:getId(Dec), true);
        default           -> wxMenu:check(Menu, wxMenuItem:getId(Def), true);
        {_, Column}       ->
            Text  = "Sorted on column \"" ++ Column ++ "\"",
            MItem = wxMenu:appendRadioItem(Menu, ?wxID_ANY, Text),
            wxMenu:check(Menu, wxMenuItem:getId(MItem), true)
    end.

addFilter(Menu, Column, Filter) when (Column == ?status) or
                                     (Column == ?prio)   or
                                     (Column == ?uid)    ->
    wxMenu:appendSeparator(Menu),
    SubMenu = wxMenu:new([]),
    appendValues(SubMenu, Column, Filter),
    SubMenuItem = wxMenuItem:new([{parentMenu, Menu}, {id, ?wxID_ANY},
                                  {text, "Filter"}, {subMenu, SubMenu},
                                  {kind, ?wxITEM_NORMAL}]),
    wxMenu:append(Menu, SubMenuItem),
    wxMenu:connect(SubMenu, command_menu_selected);
addFilter(_, _, _) ->
    ok.

appendValues(SubMenu, ?status, Val) ->
    ID1 = wxMenu:appendCheckItem(SubMenu, ?statusPlanning,   ?descPlanning),
    ID2 = wxMenu:appendCheckItem(SubMenu, ?statusInProgress, ?descInProgress),
    ID3 = wxMenu:appendCheckItem(SubMenu, ?statusDone,       ?descDone),
    ID4 = wxMenu:appendCheckItem(SubMenu, ?statusNone,       ?descNA),
    wxMenu:check(SubMenu, wxMenuItem:getId(ID1), check(?statusPlanning,   Val)),
    wxMenu:check(SubMenu, wxMenuItem:getId(ID2), check(?statusInProgress, Val)),
    wxMenu:check(SubMenu, wxMenuItem:getId(ID3), check(?statusDone,       Val)),
    wxMenu:check(SubMenu, wxMenuItem:getId(ID4), check(?statusNone,       Val));
appendValues(SubMenu, ?prio, Val) ->
    ID1 = wxMenu:appendCheckItem(SubMenu, ?prioLow,    ?descLow),
    ID2 = wxMenu:appendCheckItem(SubMenu, ?prioMedium, ?descMedium),
    ID3 = wxMenu:appendCheckItem(SubMenu, ?prioHigh,   ?descHigh),
    ID4 = wxMenu:appendCheckItem(SubMenu, ?prioNone,   ?descNA),
    wxMenu:check(SubMenu, wxMenuItem:getId(ID1), check(?prioLow,    Val)),
    wxMenu:check(SubMenu, wxMenuItem:getId(ID2), check(?prioMedium, Val)),
    wxMenu:check(SubMenu, wxMenuItem:getId(ID3), check(?prioHigh,   Val)),
    wxMenu:check(SubMenu, wxMenuItem:getId(ID4), check(?prioNone,   Val));
appendValues(SubMenu, ?uid, Val) ->
    ID1 = wxMenu:appendCheckItem(SubMenu, ?assigned, ?descAssigned),
    wxMenu:check(SubMenu, wxMenuItem:getId(ID1), check(?assigned, Val)).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
clearAndInitiate(TodoList, Rows) ->
    wxListCtrl:deleteAllItems(TodoList),
    insertRows(TodoList, Rows).

insertRows(_TodoList, 0)   -> ok;
insertRows(TodoList,  Row) ->
    wxListCtrl:insertItem(TodoList, Row, ""),
    insertRows(TodoList, Row - 1).


check(Key, Val) -> not lists:member(Key, Val).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
checkStatus(State = #guiState{user       = User,
                              activeTodo = ActiveTodo,
                              clipBoard  = ClipboardContent,
                              loggedIn   = LoggedIn}) ->
    TDown    = xrcId("todoDownTool"),
    MUp      = xrcId("moveUpTool"),
    MFiM     = xrcId("moveFirstMenu"),
    MUpM     = xrcId("moveUpMenu"),
    MDown    = xrcId("moveDownTool"),
    MDownM   = xrcId("moveDownMenu"),
    MLaM     = xrcId("moveLastMenu"),
    Cut      = xrcId("cutTool"),
    Copy     = xrcId("copyTool"),
    Paste    = xrcId("pasteTool"),
    Delete   = xrcId("deleteTool"),
    CutM     = xrcId("cutMenu"),
    CopyM    = xrcId("copyMenu"),
    PasteM   = xrcId("pasteMenu"),
    DeleteM  = xrcId("deleteMenu"),
    Forward  = xrcId("forwardTool"),
    Backup   = xrcId("backupMenuItem"),
    Restore  = xrcId("restoreMenuItem"),

    Reminder = obj("setReminderButton", State),
    Shared   = obj("shareButton",       State),
    TaskEdit = obj("taskEditPanel",     State),

    ToolBar   = State#guiState.toolBar,
    MenuBar   = State#guiState.menuBar,
    TaskList  = getTaskList(State),
    TodoList  = getTodoList(TaskList, State),
    Selected  = findSelected(TodoList) =/= -1,
    Clipboard = (ClipboardContent =/= undefined),
    AllTask   = TaskList == ?defTaskList,

    wxBitmapButton:enable(Reminder, [{enable, Selected}]),
    wxBitmapButton:enable(Shared, [{enable, Selected}]),

    NoSubTodos = case ActiveTodo of
                     {ETodo = #etodo{}, _} ->
                         not ETodo#etodo.hasSubTodo;
                     _ ->
                         false
                 end,
    case default(eTodoDB:readListCfg(User, sorted), default) of
        default ->
            wxToolBar:enableTool(ToolBar, TDown,   true),
            wxMenuBar:enable(MenuBar,     MUpM,    Selected),
            wxMenuBar:enable(MenuBar,     MFiM,    Selected),
            wxMenuBar:enable(MenuBar,     MDownM,  Selected),
            wxMenuBar:enable(MenuBar,     MLaM,    Selected),
            wxToolBar:enableTool(ToolBar, MDown,   Selected),
            wxToolBar:enableTool(ToolBar, MUp,     Selected);
        _ ->
            wxMenuBar:enable(MenuBar,     MFiM,    false),
            wxMenuBar:enable(MenuBar,     MUpM,    false),
            wxMenuBar:enable(MenuBar,     MDownM,  false),
            wxMenuBar:enable(MenuBar,     MLaM,    false),
            wxToolBar:enableTool(ToolBar, MDown,   false),
            wxToolBar:enableTool(ToolBar, MUp,     false),
            wxToolBar:enableTool(ToolBar, TDown,   false)
    end,

    wxToolBar:enableTool(ToolBar, Cut,
                         Selected and NoSubTodos and not AllTask),
    wxToolBar:enableTool(ToolBar, Paste,   Clipboard),
    wxToolBar:enableTool(ToolBar, Copy,    Selected),
    wxToolBar:enableTool(ToolBar, Delete,  Selected and NoSubTodos),
    wxToolBar:enableTool(ToolBar, Forward, Selected and (not NoSubTodos)),
    wxMenuBar:enable(MenuBar,     CutM,
                     Selected and NoSubTodos and not AllTask),
    wxMenuBar:enable(MenuBar,     PasteM,  Clipboard),
    wxMenuBar:enable(MenuBar,     CopyM,   Selected),
    wxMenuBar:enable(MenuBar,     DeleteM, Selected and NoSubTodos),
    wxMenuBar:enable(MenuBar,     Backup,  not LoggedIn),
    wxMenuBar:enable(MenuBar,     Restore, not LoggedIn),
    wxPanel:enable(TaskEdit, [{enable, Selected}]),

    checkUndoStatus(State).


checkUndoStatus(State) ->
    UndoM    = xrcId("undoMenu"),
    RedoM    = xrcId("redoMenu"),
    Undo     = xrcId("undoTool"),
    Redo     = xrcId("redoTool"),

    ToolBar  = State#guiState.toolBar,
    MenuBar  = State#guiState.menuBar,

    {UndoStatus, RedoStatus} = eTodoDB:undoStatus(),

    wxToolBar:enableTool(ToolBar, Undo,    UndoStatus),
    wxToolBar:enableTool(ToolBar, Redo,    RedoStatus),
    wxMenuBar:enable(MenuBar,     UndoM,   UndoStatus),
    wxMenuBar:enable(MenuBar,     RedoM,   RedoStatus),
    State.

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
userStatusUpdate(State = #guiState{userStatus = UserList,
                                   user       = User}) ->
    Obj          = obj("userStatusChoice", State),
    Obj2         = obj("userStatusMsg",    State),
    MsgTextWin   = obj("msgTextWin",       State),
    Index        = wxChoice:getSelection(Obj),
    Status       = wxChoice:getString(Obj, Index),
    case Status of
        "Offline" ->
            doLogout(User, State);
        _->
            setUserStatus(Status, State),
            (catch setPortrait(User, State)),
            deselectUserCheckBox(State),
            StatusMsg    = wxTextCtrl:getValue(Obj2),
            StatusUpdate = #userStatus{userName  = User,
                                       statusMsg = StatusMsg,
                                       status    = Status},
            ePluginServer:eSetStatusUpdate(User, Status, StatusMsg),
            eWeb:setStatusUpdate(User, Status, StatusMsg),
            Users = [UserStatus#userStatus.userName || UserStatus <- UserList],
            ePeerEM:sendMsg(User, Users, statusEntry,
                            {statusUpdate, StatusUpdate, getPortrait(User)}),
            setScrollBar(MsgTextWin),
            State
    end.

deselectUserCheckBox(State) ->
    %% Uncheck selection in userCheckBox.
    Obj   = obj("userCheckBox", State),
    Index = wxCheckListBox:getSelection(Obj),
    case Index of
        Index when Index >= 0 ->
            wxCheckListBox:deselect(Obj, Index);
        _ ->
            ok
    end.

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
makeETodo(#todo{uid         = Uid,
                priority    = Priority,
                status      = Status,
                doneTime    = DoneTime,
                dueTime     = DueTime,
                createTime  = CreateTime,
                comment     = Comment,
                description = Desc,
                progress    = Progress,
                sharedWith  = SharedWith,
                owner       = Owner}, User, Columns) ->

    ShareText = makeStr(default(SharedWith, [User])),
    Lists     = eTodoDB:getLists(User, Uid),

    #etodo{status         = toStr(Status),
           statusCol      = col(?status, Columns),
           statusDB       = Status,
           priority       = toStr(Priority),
           priorityCol    = col(?prio, Columns),
           priorityDB     = Priority,
           owner          = toStr(default(Owner, User)),
           ownerCol       = col(?owner, Columns),
           dueTime        = toStr(DueTime),
           dueTimeCol     = col(?dueTime, Columns),
           dueTimeDB      = DueTime,
           description    = toStr(Desc),
           descriptionCol = col(?description, Columns),
           comment        = toStr(Comment),
           commentCol     = col(?comment, Columns),
           sharedWith     = ShareText,
           sharedWithCol  = col(?sharedWith, Columns),
           sharedWithDB   = default(SharedWith, [User]),
           createTime     = toStr(CreateTime),
           createTimeCol  = col(?createTime, Columns),
           createTimeDB   = CreateTime,
           doneTime       = toStr(DoneTime),
           doneTimeCol    = col(?doneTimestamp, Columns),
           doneTimeDB     = DoneTime,
           hasSubTodo     = eTodoDB:hasSubTodo(Uid),
           uid            = toStr(Uid),
           uidCol         = col(?uid, Columns),
           uidDB          = Uid,
           progress       = Progress,
           lists          = makeStr(Lists),
           listsDB        = Lists}.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
xrcId(Id) ->
    %% Cache for faster access.
    case get({wxXrcId, Id}) of
        undefined ->
            Ret = wxXmlResource:getXRCID(Id),
            put({wxXrcId, Id}, Ret),
            Ret;
        Value ->
            Value
    end.

%%======================================================================
%% Function : sendUpdate(User, Owner, ETodo) -> ok
%% Purpose  : Send message that owner has been updated to owner.
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
sendUpdate(User, User, _ETodo) ->
    ok;
sendUpdate(User, Owner, ETodo) ->
    Users = ETodo#etodo.sharedWithDB,
    case lists:member(Owner, Users) of
        true ->
            Text = "You are the new owner of: " ++ ETodo#etodo.description,
            eTodo:systemEntry(ETodo#etodo.uidDB, Text),
            ePeerEM:sendMsg(User, [Owner],
                            {systemEntry, ETodo#etodo.uidDB}, Text);
        false ->
            %% The task isn't shared with owner.
            eLog:log(debug, ?MODULE, sendUpdate, [Owner, Users],
                     "Task not shared with owner, do not send update.", ?LINE),
            ok
    end.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
clearStatusBar(State) ->
    StatusBarObj = obj("mainStatusBar", State),
    wxStatusBar:setStatusText(StatusBarObj, "", [{number, 2}]),
    State.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
updateInfoIcon(State = #guiState{filter = Filter})
  when (Filter == undefined) or (Filter == []) ->
    InfoIcon = obj("infoIcon", State),
    Panel    = obj("mainPanel", State),
    UseFlt   = obj("checkBoxUseFilter", State),
    wxStaticBitmap:setToolTip(InfoIcon, ""),
    wxStaticBitmap:hide(InfoIcon),
    wxCheckBox:disable(UseFlt),
    wxPanel:layout(Panel);
updateInfoIcon(State) ->
    InfoIcon = obj("infoIcon", State),
    Panel    = obj("mainPanel", State),
    UseFlt   = obj("checkBoxUseFilter", State),
    Text     = "Filter is used for all columns marked with *",
    wxStaticBitmap:setToolTip(InfoIcon, Text),
    wxStaticBitmap:show(InfoIcon),
    wxCheckBox:enable(UseFlt),
    wxPanel:layout(Panel).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
updateColumns(_Filter, State = #guiState{columns = undefined}) ->
    State;
updateColumns(Filter, State = #guiState{columns = Columns}) ->
    FilterCols = [eTodoUtils:toColumn(Flt) || Flt <- Filter],
    updateColumns(FilterCols, Columns, State).

updateColumns(_FilterCols, [], State) ->
    State;
updateColumns(FilterCols, [{ColNr, Column}|Rest], State) ->
    TaskList = getTaskList(State),
    TodoList = getTodoList(TaskList, State),
    NewCol   = wxListItem:new(),
    wxListItem:setMask(NewCol, ?wxLIST_MASK_TEXT),
    case lists:member(Column, FilterCols) of
        true ->
            wxListItem:setText(NewCol, Column ++ "*");
        false ->
            wxListItem:setText(NewCol, Column)
    end,
    wxListCtrl:setColumn(TodoList, ColNr, NewCol),
    updateColumns(FilterCols, Rest, State).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
useFilter(TaskList, Filter, State) ->
    UseFlt = obj("checkBoxUseFilter", State),
    case wxCheckBox:isChecked(UseFlt) of
        true ->
            case lists:keyfind(TaskList, 1, Filter) of
                {TaskList, Flt} ->
                    Flt;
                _ ->
                    %% Get default value for all lists
                    lists:filter(fun(X) -> not is_tuple(X) end, Filter)
            end;
        false ->
            []
    end.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
findSelected(TodoList) ->
    wxListCtrl:getNextItem(TodoList, -1, [{state, ?wxLIST_STATE_SELECTED}]).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
pos(Value, List) -> pos(Value, List, []).

pos(Value, [Value | _List], Pos) -> length(Pos);
pos(Value, [_ | List], SoFar)    -> pos(Value, List, [Value | SoFar]).

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
userStatusAvailable(State) ->
    Obj1 = obj("userAvailableIcon", State),
    Obj2 = obj("userBusyIcon",      State),
    Obj3 = obj("userAwayIcon",      State),
    Obj4 = obj("userOfflineIcon",   State),
    Obj5 = obj("userStatusChoice",  State),
    Obj6 = obj("allMsgPanel",       State),

    %% Set correct icon to show
    wxStaticBitmap:show(Obj1),
    wxStaticBitmap:hide(Obj2),
    wxStaticBitmap:hide(Obj3),
    wxStaticBitmap:hide(Obj4),

    %% Enable and set combobox to available.
    wxChoice:enable(Obj5),
    setSelection(Obj5, "Available"),

    wxPanel:layout(Obj6),
    wxPanel:refresh(Obj6),
    State.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
userStatusOffline(State) ->
    Obj1 = obj("userAvailableIcon", State),
    Obj2 = obj("userBusyIcon",      State),
    Obj3 = obj("userAwayIcon",      State),
    Obj4 = obj("userOfflineIcon",   State),
    Obj5 = obj("userStatusChoice",  State),
    Obj6 = obj("allMsgPanel",       State),

    %% Set correct icon to show
    wxStaticBitmap:hide(Obj1),
    wxStaticBitmap:hide(Obj2),
    wxStaticBitmap:hide(Obj3),
    wxStaticBitmap:show(Obj4),

    %% Disable and set combo box to offline.
    setSelection(Obj5, "Offline"),
    wxChoice:disable(Obj5),

    wxPanel:layout(Obj6),
    wxPanel:refresh(Obj6),
    State.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
userStatusBusy(State) ->
    Obj1 = obj("userAvailableIcon", State),
    Obj2 = obj("userBusyIcon",      State),
    Obj3 = obj("userAwayIcon",      State),
    Obj4 = obj("userOfflineIcon",   State),
    Obj5 = obj("allMsgPanel",       State),

    %% Set correct icon to show
    wxStaticBitmap:hide(Obj1),
    wxStaticBitmap:hide(Obj3),
    wxStaticBitmap:hide(Obj4),
    wxStaticBitmap:show(Obj2),

    wxPanel:layout(Obj5),
    wxPanel:refresh(Obj5),
    State.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
userStatusAway(State) ->
    Obj1 = obj("userAvailableIcon", State),
    Obj2 = obj("userBusyIcon",      State),
    Obj3 = obj("userAwayIcon",      State),
    Obj4 = obj("userOfflineIcon",   State),
    Obj5 = obj("allMsgPanel",       State),

    %% Set correct icon to show
    wxStaticBitmap:hide(Obj1),
    wxStaticBitmap:hide(Obj2),
    wxStaticBitmap:hide(Obj4),
    wxStaticBitmap:show(Obj3),

    wxPanel:layout(Obj5),
    wxPanel:refresh(Obj5),
    State.

setUserStatus("Away",      State) -> userStatusAway(State);
setUserStatus("Busy",      State) -> userStatusBusy(State);
setUserStatus("Offline",   State) -> userStatusOffline(State);
setUserStatus("Available", State) -> userStatusAvailable(State);
setUserStatus(_Unknown,    State) -> State.

%%======================================================================
%% Function :
%% Purpose  :
%% Types    :
%%----------------------------------------------------------------------
%% Notes    :
%%======================================================================
setPeerStatus(UserStatus = #userStatus{status = "Available"}, State) ->
    Obj1 = obj("peerAvailableIcon", State),
    Obj2 = obj("peerBusyIcon",      State),
    Obj3 = obj("peerAwayIcon",      State),

    %% Set correct icon to show
    wxStaticBitmap:hide(Obj2),
    wxStaticBitmap:hide(Obj3),
    wxStaticBitmap:show(Obj1),

    setPeerStatusTextAndLayout(UserStatus, State);
setPeerStatus(UserStatus = #userStatus{status = "Busy"}, State) ->
    Obj1 = obj("peerAvailableIcon", State),
    Obj2 = obj("peerBusyIcon",      State),
    Obj3 = obj("peerAwayIcon",      State),

    %% Set correct icon to show
    wxStaticBitmap:hide(Obj1),
    wxStaticBitmap:hide(Obj3),
    wxStaticBitmap:show(Obj2),

    setPeerStatusTextAndLayout(UserStatus, State);
setPeerStatus(UserStatus = #userStatus{status = "Away"}, State) ->
    Obj1 = obj("peerAvailableIcon", State),
    Obj2 = obj("peerBusyIcon",      State),
    Obj3 = obj("peerAwayIcon",      State),

    %% Set correct icon to show
    wxStaticBitmap:hide(Obj1),
    wxStaticBitmap:hide(Obj2),
    wxStaticBitmap:show(Obj3),

    setPeerStatusTextAndLayout(UserStatus, State).

setPeerStatusTextAndLayout(#userStatus{userName  = UserName,
                                       statusMsg = Message}, State) ->
    Obj1 = obj("userStatusPanel", State),
    wxPanel:layout(Obj1),
    wxPanel:refresh(Obj1),

    PeerMessage =
        case Message of
            "" ->
                UserName;
            _ ->
                UserName ++ ": " ++ Message
        end,
    Obj2 = obj("peerStatusMsg", State),
    wxStaticText:setLabel(Obj2,   PeerMessage),
    wxStaticText:setToolTip(Obj2, PeerMessage),
    (catch setPortrait(UserName, State)),
    State.

setPortrait(Peer, State) ->
    CustomPortrait = getRootDir() ++ "/Icons/portrait_" ++ Peer ++ ".png",
    FileName = case filelib:is_file(CustomPortrait) of
                   true ->
                       getRootDir() ++ "/Icons/portrait_" ++ Peer ++ ".png";
                   false ->
                       getRootDir() ++ "/Icons/portrait.png"
               end,
    Png = wxImage:new(FileName),
    Bitmap = wxBitmap:new(Png),
    wxBitmap:setHeight(Bitmap, 64),
    wxBitmap:setWidth(Bitmap, 64),
    wxStaticBitmap:setBitmap(obj("portraitPeerIcon", State), Bitmap).

getPortrait(Peer) ->
    CustomPortrait = getRootDir() ++ "/Icons/portrait_" ++ Peer ++ ".png",
    case filelib:is_file(CustomPortrait) of
        true ->
            {ok, Bin} = file:read_file(CustomPortrait),
            Bin;
        false ->
            undefined
    end.

setPeerStatusIfNeeded(State = #guiState{userStatus = Users}) ->
    Obj   = obj("userCheckBox", State),
    Index = wxCheckListBox:getSelection(Obj),
    User  = wxCheckListBox:getString(Obj, Index),
    case lists:keyfind(User, #userStatus.userName, Users) of
        UserStatus when is_record(UserStatus, userStatus) ->
            setPeerStatus(UserStatus, State);
        false ->
            clearPeerStatus(State)
    end,
    State.

clearPeerStatus(State) ->
    Obj1 = obj("peerAvailableIcon", State),
    Obj2 = obj("peerBusyIcon",      State),
    Obj3 = obj("peerAwayIcon",      State),

    %% Set correct icon to show
    wxStaticBitmap:hide(Obj1),
    wxStaticBitmap:hide(Obj2),
    wxStaticBitmap:hide(Obj3),

    Obj4 = obj("userStatusPanel", State),
    wxPanel:layout(Obj4),
    wxPanel:refresh(Obj4),

    Obj5 = obj("peerStatusMsg", State),
    PeerMessage = "Select a peer to show status information here...",
    wxStaticText:setLabel(Obj5,   PeerMessage),
    wxStaticText:setToolTip(Obj5, PeerMessage),
    State.

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

saveColumnSizes(State = #guiState{columns = Columns,
                                  user    = User}) ->
    TaskList  = getTaskList(State),
    TodoList  = getTodoList(TaskList, State),
    [saveColumnSizes(TodoList, User, Col, Desc) || {Col, Desc} <- Columns].

saveColumnSizes(TodoList, User, Col, Desc) ->
    InternalName = eTodoUtils:taskInternal(Desc),
    ColumnSize   = wxListCtrl:getColumnWidth(TodoList, Col),
    case eTodoDB:readListCfg(User, InternalName, visible) of
        false ->
            ok;
        _ ->
            eTodoDB:saveListCfg(User, InternalName, columnWidth, ColumnSize)
    end.

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

setColumnWidth(TodoList, User, Col, ?description) ->
    setColumnWidth(TodoList, User, Col, ?description, 200);
setColumnWidth(TodoList, User, Col, ?status) ->
    setColumnWidth(TodoList, User, Col, ?status, 110);
setColumnWidth(TodoList, User, Col, ?comment) ->
    setColumnWidth(TodoList, User, Col, ?comment, 100);
setColumnWidth(TodoList, User, Col, Field) ->
    setColumnWidth(TodoList, User, Col, Field, ?wxLIST_AUTOSIZE_USEHEADER).

setColumnWidth(TodoList, User, Col, Desc, Default) ->
    TaskInternal = eTodoUtils:taskInternal(Desc),
    case eTodoDB:readListCfg(User, TaskInternal, visible) of
        false ->
            wxListCtrl:setColumnWidth(TodoList, Col, 0);
        _ ->
            case eTodoDB:readListCfg(User, TaskInternal, columnWidth) of
                Num when is_integer(Num) and (Num > 0) ->
                    wxListCtrl:setColumnWidth(TodoList, Col, Num);
                _ ->
                    wxListCtrl:setColumnWidth(TodoList, Col, Default)
            end
    end.

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
generateWorkLog(State = #guiState{user = User}) ->
    Obj1      = obj("workLogStartDate", State),
    Obj2      = obj("workLogReport",    State),
    DateTime  = wxDatePickerCtrl:getValue(Obj1),
    {Date, _} = DateTime,
    Report    = eHtml:makeWorkLogReport(User, Date),
    wxHtmlWindow:setPage(Obj2, Report),
    State.

