require "cases/helper"
require 'models/developer'
require 'models/project'
require 'models/company'

class HasOneAssociationsTest < ActiveRecord::TestCase
  fixtures :accounts, :companies, :developers, :projects, :developers_projects

  def setup
    Account.destroyed_account_ids.clear
  end

  def test_has_one
    assert_equal companies(:first_firm).account, Account.find(1)
    assert_equal Account.find(1).credit_limit, companies(:first_firm).account.credit_limit
  end
  
  def test_has_one_cache_nils
    firm = companies(:another_firm)
    assert_queries(1) { assert_nil firm.account }
    assert_queries(0) { assert_nil firm.account }

    firms = Firm.find(:all, :include => :account)
    assert_queries(0) { firms.each(&:account) }
  end

  def test_with_select
    assert_equal Firm.find(1).account_with_select.attributes.size, 2
    assert_equal Firm.find(1, :include => :account_with_select).account_with_select.attributes.size, 2
  end

  def test_finding_using_primary_key
    firm = companies(:first_firm)
    assert_equal Account.find_by_firm_id(firm.id), firm.account
    firm.firm_id = companies(:rails_core).id
    assert_equal accounts(:rails_core_account), firm.account_using_primary_key
  end

  def test_can_marshal_has_one_association_with_nil_target
    firm = Firm.new
    assert_nothing_raised do
      assert_equal firm.attributes, Marshal.load(Marshal.dump(firm)).attributes
    end

    firm.account
    assert_nothing_raised do
      assert_equal firm.attributes, Marshal.load(Marshal.dump(firm)).attributes
    end
  end

  def test_proxy_assignment
    company = companies(:first_firm)
    assert_nothing_raised { company.account = company.account }
  end

  def test_triple_equality
    assert Account === companies(:first_firm).account
    assert companies(:first_firm).account === Account
  end

  def test_type_mismatch
    assert_raises(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).account = 1 }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { companies(:first_firm).account = Project.find(1) }
  end

  def test_natural_assignment
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    apple.account = citibank
    assert_equal apple.id, citibank.firm_id
  end

  def test_natural_assignment_to_nil
    old_account_id = companies(:first_firm).account.id
    companies(:first_firm).account = nil
    companies(:first_firm).save
    assert_nil companies(:first_firm).account
    # account is dependent, therefore is destroyed when reference to owner is lost
    assert_raises(ActiveRecord::RecordNotFound) { Account.find(old_account_id) }
  end

  def test_assignment_without_replacement
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    apple.account = citibank
    assert_equal apple.id, citibank.firm_id

    hsbc = apple.build_account({ :credit_limit => 20}, false)
    assert_equal apple.id, hsbc.firm_id
    hsbc.save
    assert_equal apple.id, citibank.firm_id

    nykredit = apple.create_account({ :credit_limit => 30}, false)
    assert_equal apple.id, nykredit.firm_id
    assert_equal apple.id, citibank.firm_id
    assert_equal apple.id, hsbc.firm_id
  end

  def test_assignment_without_replacement_on_create
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    apple.account = citibank
    assert_equal apple.id, citibank.firm_id

    hsbc = apple.create_account({:credit_limit => 10}, false)
    assert_equal apple.id, hsbc.firm_id
    hsbc.save
    assert_equal apple.id, citibank.firm_id
  end

  def test_dependence
    num_accounts = Account.count

    firm = Firm.find(1)
    assert !firm.account.nil?
    account_id = firm.account.id
    assert_equal [], Account.destroyed_account_ids[firm.id]

    firm.destroy
    assert_equal num_accounts - 1, Account.count
    assert_equal [account_id], Account.destroyed_account_ids[firm.id]
  end

  def test_exclusive_dependence
    num_accounts = Account.count

    firm = ExclusivelyDependentFirm.find(9)
    assert !firm.account.nil?
    account_id = firm.account.id
    assert_equal [], Account.destroyed_account_ids[firm.id]

    firm.destroy
    assert_equal num_accounts - 1, Account.count
    assert_equal [], Account.destroyed_account_ids[firm.id]
  end

  def test_dependence_with_nil_associate
    firm = DependentFirm.new(:name => 'nullify')
    firm.save!
    assert_nothing_raised { firm.destroy }
  end

  def test_succesful_build_association
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save

    account = firm.build_account("credit_limit" => 1000)
    assert account.save
    assert_equal account, firm.account
  end

  def test_failing_build_association
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save

    account = firm.build_account
    assert !account.save
    assert_equal "can't be empty", account.errors.on("credit_limit")
  end

  def test_build_association_twice_without_saving_affects_nothing
    count_of_account = Account.count
    firm = Firm.find(:first)
    account1 = firm.build_account("credit_limit" => 1000)
    account2 = firm.build_account("credit_limit" => 2000)

    assert_equal count_of_account, Account.count
  end

  def test_create_association
    firm = Firm.create(:name => "GlobalMegaCorp")
    account = firm.create_account(:credit_limit => 1000)
    assert_equal account, firm.reload.account
  end

  def test_build
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save

    firm.account = account = Account.new("credit_limit" => 1000)
    assert_equal account, firm.account
    assert account.save
    assert_equal account, firm.account
  end

  def test_build_before_child_saved
    firm = Firm.find(1)

    account = firm.account.build("credit_limit" => 1000)
    assert_equal account, firm.account
    assert account.new_record?
    assert firm.save
    assert_equal account, firm.account
    assert !account.new_record?
  end

  def test_build_before_either_saved
    firm = Firm.new("name" => "GlobalMegaCorp")

    firm.account = account = Account.new("credit_limit" => 1000)
    assert_equal account, firm.account
    assert account.new_record?
    assert firm.save
    assert_equal account, firm.account
    assert !account.new_record?
  end

  def test_failing_build_association
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save

    firm.account = account = Account.new
    assert_equal account, firm.account
    assert !account.save
    assert_equal account, firm.account
    assert_equal "can't be empty", account.errors.on("credit_limit")
  end

  def test_create
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save
    firm.account = account = Account.create("credit_limit" => 1000)
    assert_equal account, firm.account
  end

  def test_create_before_save
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.account = account = Account.create("credit_limit" => 1000)
    assert_equal account, firm.account
  end

  def test_dependence_with_missing_association
    Account.destroy_all
    firm = Firm.find(1)
    assert firm.account.nil?
    firm.destroy
  end

  def test_dependence_with_missing_association_and_nullify
    Account.destroy_all
    firm = DependentFirm.find(:first)
    assert firm.account.nil?
    firm.destroy
  end

  def test_assignment_before_parent_saved
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.account = a = Account.find(1)
    assert firm.new_record?
    assert_equal a, firm.account
    assert firm.save
    assert_equal a, firm.account
    assert_equal a, firm.account(true)
  end

  def test_finding_with_interpolated_condition
    firm = Firm.find(:first)
    superior = firm.clients.create(:name => 'SuperiorCo')
    superior.rating = 10
    superior.save
    assert_equal 10, firm.clients_with_interpolated_conditions.first.rating
  end

  def test_assignment_before_child_saved
    firm = Firm.find(1)
    firm.account = a = Account.new("credit_limit" => 1000)
    assert !a.new_record?
    assert_equal a, firm.account
    assert_equal a, firm.account
    assert_equal a, firm.account(true)
  end
  
  def test_save_fails_for_invalid_has_one
    firm = Firm.find(:first)
    assert firm.valid?
    
    firm.account = Account.new
    
    assert !firm.account.valid?
    assert !firm.valid?
    assert !firm.save
    assert_equal "is invalid", firm.errors.on("account")
  end


  def test_save_succeeds_for_invalid_has_one_with_validate_false
    firm = Firm.find(:first)
    assert firm.valid?

    firm.unvalidated_account = Account.new

    assert !firm.unvalidated_account.valid?
    assert firm.valid?
    assert firm.save
  end

  def test_assignment_before_either_saved
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.account = a = Account.new("credit_limit" => 1000)
    assert firm.new_record?
    assert a.new_record?
    assert_equal a, firm.account
    assert firm.save
    assert !firm.new_record?
    assert !a.new_record?
    assert_equal a, firm.account
    assert_equal a, firm.account(true)
  end

  def test_not_resaved_when_unchanged
    firm = Firm.find(:first, :include => :account)
    firm.name += '-changed'
    assert_queries(1) { firm.save! }

    firm = Firm.find(:first)
    firm.account = Account.find(:first)
    assert_queries(Firm.partial_updates? ? 0 : 1) { firm.save! }

    firm = Firm.find(:first).clone
    firm.account = Account.find(:first)
    assert_queries(2) { firm.save! }

    firm = Firm.find(:first).clone
    firm.account = Account.find(:first).clone
    assert_queries(2) { firm.save! }
  end

  def test_save_still_works_after_accessing_nil_has_one
    jp = Company.new :name => 'Jaded Pixel'
    jp.dummy_account.nil?

    assert_nothing_raised do
      jp.save!
    end
  end

  def test_cant_save_readonly_association
    assert_raise(ActiveRecord::ReadOnlyRecord) { companies(:first_firm).readonly_account.save!  }
    assert companies(:first_firm).readonly_account.readonly?
  end

end
