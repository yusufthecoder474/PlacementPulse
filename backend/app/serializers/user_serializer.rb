# Shapes the user object exactly as the API contract requires. Decimals
# are rendered as JSON numbers (7.5, not "7.5") via to_f.
class UserSerializer
  def self.call(user)
    {
      id: user.id,
      email: user.email,
      role: user.role,
      branch: user.branch,
      cgpa: user.cgpa&.to_f,
      class_x_percentage: user.class_x_percentage&.to_f,
      class_xii_percentage: user.class_xii_percentage&.to_f,
      standing_arrears: user.standing_arrears
    }
  end
end
