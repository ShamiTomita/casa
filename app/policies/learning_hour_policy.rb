class LearningHourPolicy < ApplicationPolicy
  def show?
    record.user_id == @user.id
  end

  def new?
    @user.volunteer?
  end

  alias_method :edit?, :show?
  alias_method :destroy?, :show?
  alias_method :create?, :show?
  alias_method :update?, :show?
end
