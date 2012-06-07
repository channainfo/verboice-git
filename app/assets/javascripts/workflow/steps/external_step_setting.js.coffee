onWorkflow ->
  class window.ExternalStepSetting
    constructor: (parent, attrs) ->

      @name = attrs.name
      @display_name = attrs.display_name

      @value = ko.observable attrs.value
      @step_id = ko.observable attrs.step
      @variable = ko.observable attrs.variable

      @content_kind = ko.observable (if attrs.variable? and attrs.variable != ''
          'variable'
        else if attrs.step? and attrs.step != ''
          'step'
        else
          'value')

      @parent = parent

    to_hash: () =>
      name: @name
      step: if @content_kind() == 'step' then @step_id() else null
      variable: if @content_kind() == 'variable' then @variable() else null
      value: if @content_kind() == 'value' then @value() else null

    variable_or_step_name: () =>
      if @variable()
        @variable()
      else if @step_id()
        workflow.get_step(parseInt(@step_id())).name()
      else
        ''

    available_variables: () =>
      workflow.all_variables().sort()

    available_steps: () =>
      {name: step.name(), value: step.id} for step in workflow.steps() when (step.type() == 'capture') || (step.type() == 'menu')

    on_step_removed: (step) =>
      @step_id(null) if step.id == parseInt(@step_id())

    on_begin_edition: () =>
      @content_kind_tmp = @content_kind()
      @value_tmp = @value()
      @variable_tmp = @variable()
      @step_id_tmp = @step_id()

    save: () =>
      @exit()

    cancel: () =>
      @content_kind(@content_kind_tmp)
      @value(@value_tmp)
      @variable(@variable_tmp)
      @step_id(@step_id_tmp)
      @exit()

    exit: () =>
      @parent.current_editing_setting(null)
