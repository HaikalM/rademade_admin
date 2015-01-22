# -*- encoding : utf-8 -*-
module RademadeAdmin
  class ModelController < RademadeAdmin::AbstractController

    extend RademadeAdmin::ModelOptions

    include RademadeAdmin::InstanceOptions
    include RademadeAdmin::Templates
    include RademadeAdmin::Notifier
    
    helper ::RademadeAdmin::FieldHelper
    helper ::RademadeAdmin::FormHelper
    helper ::RademadeAdmin::UriHelper

    before_filter :load_options, :additional_options
    before_filter :sortable_service, :only => [:index]

    def create
      authorize! :create, model_class
      saver = RademadeAdmin::Saver.new(model_info, params)
      saver.create_model
      saver.save_data
      success_insert saver.item
    rescue Exception => e
      render_record_errors e
    end

    def update
      authorize! :update, model_class
      saver = RademadeAdmin::Saver.new(model_info, params)
      saver.find_model
      saver.save_data
      success_update saver.item
    rescue Exception => e
      render_record_errors e
    end

    def destroy
      authorize! :destroy, model_class
      @item = model.find(params[:id])
      @item.delete if @item
      success_delete @item
    end

    def autocomplete
      authorize! :read, model_class
      conditions = Search::Conditions::Autocomplete.new(params, model_info.data_items)
      @items = Search::Searcher.new(model_info).search(conditions)
      render :json => Autocomplete::BaseSerializer.new(@items)
    end

    def link_autocomplete
      authorize! :read, model_class

      relation_service = RademadeAdmin::RelationService.new
      @related_model_info = relation_service.related_model_info(model_info, params[:relation])

      conditions = Search::Conditions::Autocomplete.new(params, @related_model_info.data_items)
      @items = Search::Searcher.new(@related_model_info).search(conditions)
      render :json => Autocomplete::LinkSerializer.new(@items, model.find(params[:id]), params[:relation])
    end

    def index
      authorize! :read, model_class
      list_breadcrumbs
      @items = index_items
      respond_to do |format|
        format.html { render_template }
        format.json { render :json => @items }
      end
    end

    def new
      authorize! :create, model_class
      @with_create_and_return_button = true

      @item = model.new

      new_breadcrumbs
      render_template
    end

    def edit
      authorize! :update, model_class
      @with_create_and_return_button = true

      @item = model.find(params[:id])

      edit_breadcrumbs
      render_template
    end

    def related
      authorize! :read, model_class

      #rm_todo extract relation service
      relation_service = RademadeAdmin::RelationService.new
      @related_model_info = relation_service.related_model_info(model_info, params[:relation])

      @item = model.find(params[:id])
      search_params = params.except(:id)
      conditions = Search::Conditions::RelatedList.new(@item, search_params, @related_model_info.data_items)
      @items = Search::Searcher.new(@related_model_info).search(conditions)

      @sortable_service = RademadeAdmin::SortableService.new(@related_model_info, search_params)

      respond_to do |format|
        format.html {
          related_breadcrumbs
          render_template
        }
        format.json { render :json => Autocomplete::BaseSerializer.new(@items) }
      end
    end

    def related_add
      @item = model.find(params[:id])
      linker = Linker.new(model_info, @item, params[:relation])
      linker.link(params[:related_id])
      success_link
    end

    def related_destroy
      @item = model.find(params[:id])
      linker = Linker.new(model_info, @item, params[:relation])
      linker.unlink(params[:related_id])
      success_unlink
    end

    def show
      authorize! :read, model_class
      @item = model.find(params[:id])
      respond_to do |format|
        format.html { redirect_to :action => 'index' }
        format.json { render :json => @item }
      end
    end

    def form
      authorize! :read, model_class
      @item = params[:id].blank? ? model.new : model.find(params[:id])
      render form_template_path(true), :layout => false
    end

    def sort
      sortable_service.sort_items
      success_action
    end

    protected

    def index_items
      conditions = Search::Conditions::List.new(params, model_info.data_items)
      Search::Searcher.new(model_info).search(conditions)
    end

    def model
      @model ||= model_info.model
    end

    def render_template(template = action_name)
      render abstract_template(template)
    end

    def sortable_service
      @sortable_service ||= RademadeAdmin::SortableService.new(model_info, params)
    end

    def additional_options
      MenuCell.current_model = model
    end

    def render_record_errors(e)
      if e.respond_to? :record
        render_errors e.record.errors
      else
        render_errors e.message
      end
    end

  end
end
