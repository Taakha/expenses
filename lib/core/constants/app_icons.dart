import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/widgets.dart';

/// Single source of truth for every icon used in Money Wise.
///
/// All screens must reference icons from here — never use [Icons] (Material)
/// or any other icon library directly.
class AppIcons {
  const AppIcons._();

  // ── Navigation ──────────────────────────────────────────────────────────────
  static const home = BootstrapIcons.house;
  static const homeFill = BootstrapIcons.house_fill;
  static const activity = BootstrapIcons.receipt;
  static const activityFill = BootstrapIcons.receipt_cutoff;
  static const budgets = BootstrapIcons.pie_chart;
  static const budgetsFill = BootstrapIcons.pie_chart_fill;
  static const reports = BootstrapIcons.graph_up;
  static const reportsFill = BootstrapIcons.graph_up_arrow;
  static const profile = BootstrapIcons.person_circle;
  static const profileFill = BootstrapIcons.person_fill;

  // ── Dashboard ───────────────────────────────────────────────────────────────
  static const logo = BootstrapIcons.wallet2;
  static const totalBalance = BootstrapIcons.wallet2;
  static const incomeArrow = BootstrapIcons.arrow_down_left;
  static const expenseArrow = BootstrapIcons.arrow_up_right;
  static const transfer = BootstrapIcons.arrow_left_right;
  static const refund = BootstrapIcons.arrow_counterclockwise;
  static const notification = BootstrapIcons.bell;
  static const notificationFill = BootstrapIcons.bell_fill;
  static const syncDone = BootstrapIcons.cloud_check;
  static const syncPending = BootstrapIcons.cloud_upload;
  static const syncOffline = BootstrapIcons.cloud_slash;
  static const syncError = BootstrapIcons.exclamation_triangle;

  // ── Accounts ────────────────────────────────────────────────────────────────
  static const accountCash = BootstrapIcons.cash_coin;
  static const accountBank = BootstrapIcons.bank;
  static const accountMobile = BootstrapIcons.phone;
  static const accountSavings = BootstrapIcons.piggy_bank;
  static const accountOther = BootstrapIcons.wallet;
  static const addAccount = BootstrapIcons.plus_circle;
  static const archiveAccount = BootstrapIcons.archive;
  static const overdraft = BootstrapIcons.exclamation_triangle;

  // ── Transactions ────────────────────────────────────────────────────────────
  static const income = BootstrapIcons.arrow_down_left_circle;
  static const incomeFill = BootstrapIcons.arrow_down_left_circle_fill;
  static const expense = BootstrapIcons.arrow_up_right_circle;
  static const expenseFill = BootstrapIcons.arrow_up_right_circle_fill;
  static const addTx = BootstrapIcons.plus_circle_fill;
  static const editTx = BootstrapIcons.pencil_square;
  static const deleteTx = BootstrapIcons.trash3;
  static const receipt = BootstrapIcons.receipt;
  static const receiptAttach = BootstrapIcons.paperclip;
  static const paymentMethod = BootstrapIcons.credit_card_2_front;
  static const search = BootstrapIcons.search;
  static const filter = BootstrapIcons.funnel;
  static const sort = BootstrapIcons.sort_down;
  static const exportCsv = BootstrapIcons.file_earmark_spreadsheet;
  static const exportPdf = BootstrapIcons.file_earmark_pdf;

  // ── Budgets ─────────────────────────────────────────────────────────────────
  static const budgetCard = BootstrapIcons.pie_chart;
  static const budgetAdd = BootstrapIcons.plus_circle;
  static const budgetAlert = BootstrapIcons.exclamation_circle;
  static const budgetExceeded = BootstrapIcons.x_circle;
  static const budgetOk = BootstrapIcons.check_circle;
  static const category = BootstrapIcons.tag;

  // ── Savings ─────────────────────────────────────────────────────────────────
  static const savingsGoal = BootstrapIcons.piggy_bank;
  static const goalAdd = BootstrapIcons.plus_circle;
  static const goalComplete = BootstrapIcons.patch_check_fill;
  static const goalFlag = BootstrapIcons.flag;
  static const contribute = BootstrapIcons.plus_lg;
  static const withdraw = BootstrapIcons.dash_lg;
  static const goalTarget = BootstrapIcons.bullseye;

  // ── Reports ─────────────────────────────────────────────────────────────────
  static const barChart = BootstrapIcons.bar_chart_line;
  static const pieChart = BootstrapIcons.pie_chart;
  static const trendUp = BootstrapIcons.graph_up_arrow;
  static const trendDown = BootstrapIcons.graph_down_arrow;
  static const cashFlow = BootstrapIcons.cash_stack;
  static const period = BootstrapIcons.calendar3;

  // ── Debts ───────────────────────────────────────────────────────────────────
  static const debtBorrowed = BootstrapIcons.arrow_up_right_circle;
  static const debtLent = BootstrapIcons.arrow_down_left_circle;
  static const debtRepay = BootstrapIcons.check2_circle;
  static const debtCollect = BootstrapIcons.coin;
  static const dueDate = BootstrapIcons.calendar_event;
  static const person = BootstrapIcons.person;

  // ── Recurring ───────────────────────────────────────────────────────────────
  static const recurring = BootstrapIcons.arrow_repeat;
  static const pause = BootstrapIcons.pause_circle;
  static const resume = BootstrapIcons.play_circle;
  static const frequency = BootstrapIcons.clock_history;

  // ── Notifications ───────────────────────────────────────────────────────────
  static const notifBudget = BootstrapIcons.pie_chart;
  static const notifGoal = BootstrapIcons.piggy_bank;
  static const notifInfo = BootstrapIcons.info_circle;
  static const markRead = BootstrapIcons.check_all;
  static const deleteNotif = BootstrapIcons.trash3;

  // ── Profile & settings ──────────────────────────────────────────────────────
  static const settings = BootstrapIcons.gear;
  static const settingsFill = BootstrapIcons.gear_fill;
  static const theme = BootstrapIcons.palette2;
  static const currency = BootstrapIcons.currency_exchange;
  static const security = BootstrapIcons.shield_lock;
  static const biometric = BootstrapIcons.fingerprint;
  static const signOut = BootstrapIcons.box_arrow_right;
  static const deleteAccount = BootstrapIcons.person_x;
  static const editProfile = BootstrapIcons.pencil;

  // ── Forms ───────────────────────────────────────────────────────────────────
  static const amount = BootstrapIcons.cash_coin;
  static const description = BootstrapIcons.card_text;
  static const notes = BootstrapIcons.journal_text;
  static const dateField = BootstrapIcons.calendar3;
  static const emailField = BootstrapIcons.envelope;
  static const passwordField = BootstrapIcons.lock;
  static const eyeShow = BootstrapIcons.eye;
  static const eyeHide = BootstrapIcons.eye_slash;
  static const nameField = BootstrapIcons.person;
  static const phoneField = BootstrapIcons.telephone;
  static const chevronRight = BootstrapIcons.chevron_right;
  static const chevronDown = BootstrapIcons.chevron_down;
  static const checkmark = BootstrapIcons.check_lg;
  static const back = BootstrapIcons.arrow_left;
  static const close = BootstrapIcons.x_lg;
  static const info = BootstrapIcons.info_circle;
  static const warning = BootstrapIcons.exclamation_triangle;
  static const success = BootstrapIcons.check_circle;

  // ── Backup & sync ───────────────────────────────────────────────────────────
  static const backup = BootstrapIcons.cloud_arrow_up;
  static const restore = BootstrapIcons.cloud_arrow_down;
  static const conflict = BootstrapIcons.exclamation_diamond;
  static const verified = BootstrapIcons.patch_check;
  static const syncRefresh = BootstrapIcons.arrow_repeat;

  // ── Categories ──────────────────────────────────────────────────────────────
  static const catFood = BootstrapIcons.egg_fried;
  static const catAccom = BootstrapIcons.house_door;
  static const catTransport = BootstrapIcons.bus_front;
  static const catEducation = BootstrapIcons.book;
  static const catComms = BootstrapIcons.wifi;
  static const catShopping = BootstrapIcons.bag;
  static const catHealth = BootstrapIcons.heart_pulse;
  static const catEntertain = BootstrapIcons.film;
  static const catBills = BootstrapIcons.receipt;
  static const catPersonal = BootstrapIcons.person_check;
  static const catSalary = BootstrapIcons.briefcase;
  static const catBusiness = BootstrapIcons.graph_up;
  static const catAllowance = BootstrapIcons.cash;
  static const catGift = BootstrapIcons.gift;
  static const catFreelance = BootstrapIcons.laptop;
  static const catOther = BootstrapIcons.three_dots;

  /// Returns the right category icon for a given category name.
  static IconData forCategory(String name, {bool income = false}) {
    return switch (name.toLowerCase()) {
      'salary' => catSalary,
      'business' => catBusiness,
      'allowance' || 'allowances' => catAllowance,
      'scholarship' => catEducation,
      'freelance' => catFreelance,
      'gift' => catGift,
      'food' || 'groceries' => catFood,
      'accommodation' || 'rent' => catAccom,
      'transport' => catTransport,
      'education' => catEducation,
      'communication' => catComms,
      'shopping' => catShopping,
      'personal care' => catPersonal,
      'entertainment' => catEntertain,
      'health' => catHealth,
      'bills' => catBills,
      _ => income ? catSalary : catOther,
    };
  }

  static IconData forCategoryKey(String key) {
    return switch (key) {
      'food' => catFood,
      'accommodation' => catAccom,
      'transport' => catTransport,
      'education' => catEducation,
      'communication' => catComms,
      'shopping' => catShopping,
      'personal' => catPersonal,
      'entertainment' => catEntertain,
      'health' => catHealth,
      'bills' => catBills,
      'income' => catSalary,
      'gift' => catGift,
      'other' => catOther,
      _ => category,
    };
  }
}
