class ProjectsController < ApplicationController

  before_filter :find_author

  def index
    @projects = Project.all
  end

  def show
    @project = Project.find(params[:id])
    @reports = @project.reports.limit(100)
    if @reports.size > 0
      @problems = @author ? @author.current_problems_in(@project) : @reports.first.problems
      @results = @problems.group_by(&:result)
    end
  end

  def new
    @project = Project.new
  end

  def edit
    @project = Project.find(params[:id])
  end

  def create
    @project = Project.new(params[:project])

    if @project.save
      redirect_to([@project, :metrics], :notice => '<strong>Project imported.</strong> Now configure the metrics for your project!'.html_safe)
    else
      render :action => "new"
    end
  end

  def update
    @project = Project.find(params[:id])

    if @project.update_attributes(params[:project])
      redirect_to(@project, :notice => 'Changes saved.')
    else
      render :action => "edit"
    end
  end

  def destroy
    @project = Project.find(params[:id])
    @project.destroy
    redirect_to(projects_url)
  end

  private

  def find_author
    @author = Author.find(params[:author_id]) if params[:author_id]
  end
end
