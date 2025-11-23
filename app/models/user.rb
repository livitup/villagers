class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Devise handles email validation, but we keep format validation
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end
