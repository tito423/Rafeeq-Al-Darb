(function (root) {
  'use strict';
  const messages = {
    ar: { welcome: 'تسجيل دخول المراجع', explanation: 'ادخل بحساب Google المصرّح له. ملاحظاتك بتفضل محفوظة على الجهاز، والمزامنة تحتاج تسجيل الدخول.', close: 'متابعة على الجهاز', account: 'تغيير الحساب', reviewer: 'المراجع', signIn: 'سجّل الدخول للمزامنة', denied: 'الحساب ده مش مصرح له بالمراجعة.', failed: 'تعذّر تسجيل الدخول. ملاحظاتك لسه محفوظة على الجهاز.', loading: 'جارٍ التحقق من الحساب…', offline: 'ملاحظاتك محفوظة على الجهاز؛ اتصال الإنترنت مطلوب لتسجيل الدخول.', saving: 'جارٍ الحفظ…', saved: 'حُفظت على الموقع', retry: 'تعذّر الحفظ — الملاحظات محفوظة وهتتعاد محاولة إرسالها.', legacy: 'ملاحظات الجهاز القديمة محفوظة باسم مختلف، ومش هتترفع باسم الحساب ده.', exportLegacy: 'صدّر ملاحظات الجهاز القديمة', language: 'اللغة' },
    en: { welcome: 'Reviewer sign-in', explanation: 'Use an authorized Google account. Notes remain on this device; syncing requires sign-in.', close: 'Continue on this device', account: 'Change account', reviewer: 'Reviewer', signIn: 'Sign in to sync', denied: 'This account is not authorized to review.', failed: 'Sign-in failed. Your notes are still saved on this device.', loading: 'Checking the account…', offline: 'Your notes are saved on this device. Internet access is required to sign in.', saving: 'Saving…', saved: 'Saved to the site', retry: 'Unable to save — your notes remain saved and will be sent again.', legacy: 'Older device notes belong to a different name and will not be uploaded under this account.', exportLegacy: 'Export older device notes', language: 'Language' },
    fr: { welcome: 'Connexion du réviseur', explanation: 'Utilisez un compte Google autorisé. Les notes restent sur cet appareil ; la synchronisation nécessite une connexion.', close: 'Continuer sur cet appareil', account: 'Changer de compte', reviewer: 'Réviseur', signIn: 'Se connecter pour synchroniser', denied: 'Ce compte n’est pas autorisé à réviser.', failed: 'La connexion a échoué. Vos notes restent enregistrées sur cet appareil.', loading: 'Vérification du compte…', offline: 'Vos notes sont enregistrées sur cet appareil. Internet est nécessaire pour vous connecter.', saving: 'Enregistrement…', saved: 'Enregistré sur le site', retry: 'Enregistrement impossible — vos notes sont conservées et seront renvoyées.', legacy: 'Les anciennes notes portent un autre nom et ne seront pas envoyées sous ce compte.', exportLegacy: 'Exporter les anciennes notes', language: 'Langue' },
    es: { welcome: 'Acceso del revisor', explanation: 'Usa una cuenta de Google autorizada. Las notas permanecen en este dispositivo; sincronizar requiere iniciar sesión.', close: 'Continuar en este dispositivo', account: 'Cambiar de cuenta', reviewer: 'Revisor', signIn: 'Inicia sesión para sincronizar', denied: 'Esta cuenta no está autorizada para revisar.', failed: 'No se pudo iniciar sesión. Tus notas siguen guardadas en este dispositivo.', loading: 'Comprobando la cuenta…', offline: 'Tus notas están guardadas en este dispositivo. Necesitas internet para iniciar sesión.', saving: 'Guardando…', saved: 'Guardado en el sitio', retry: 'No se pudo guardar — tus notas se conservan y se volverán a enviar.', legacy: 'Las notas antiguas tienen otro nombre y no se enviarán con esta cuenta.', exportLegacy: 'Exportar las notas antiguas', language: 'Idioma' },
    pt: { welcome: 'Entrada do revisor', explanation: 'Use uma conta Google autorizada. As notas permanecem neste dispositivo; a sincronização exige iniciar sessão.', close: 'Continuar neste dispositivo', account: 'Mudar de conta', reviewer: 'Revisor', signIn: 'Inicie sessão para sincronizar', denied: 'Esta conta não está autorizada a rever.', failed: 'Não foi possível iniciar sessão. As suas notas continuam guardadas neste dispositivo.', loading: 'A verificar a conta…', offline: 'As suas notas estão guardadas neste dispositivo. É necessária internet para iniciar sessão.', saving: 'A guardar…', saved: 'Guardado no site', retry: 'Não foi possível guardar — as notas estão preservadas e serão reenviadas.', legacy: 'As notas antigas têm outro nome e não serão enviadas com esta conta.', exportLegacy: 'Exportar as notas antigas', language: 'Idioma' },
    ru: { welcome: 'Вход рецензента', explanation: 'Войдите через разрешённый аккаунт Google. Заметки остаются на устройстве; для синхронизации нужен вход.', close: 'Продолжить на устройстве', account: 'Сменить аккаунт', reviewer: 'Рецензент', signIn: 'Войти для синхронизации', denied: 'Этому аккаунту не разрешено рецензирование.', failed: 'Не удалось войти. Заметки по-прежнему сохранены на устройстве.', loading: 'Проверка аккаунта…', offline: 'Заметки сохранены на устройстве. Для входа нужен интернет.', saving: 'Сохранение…', saved: 'Сохранено на сайте', retry: 'Не удалось сохранить — заметки сохранены локально и будут отправлены повторно.', legacy: 'Старые заметки записаны под другим именем и не будут отправлены от этого аккаунта.', exportLegacy: 'Экспортировать старые заметки', language: 'Язык' },
    ur: { welcome: 'مبصر کا سائن اِن', explanation: 'مجاز Google اکاؤنٹ استعمال کریں۔ نوٹس اس آلے پر محفوظ رہتے ہیں؛ ہم وقت سازی کے لیے سائن اِن ضروری ہے۔', close: 'اس آلے پر جاری رکھیں', account: 'اکاؤنٹ تبدیل کریں', reviewer: 'مبصر', signIn: 'ہم وقت سازی کے لیے سائن اِن کریں', denied: 'اس اکاؤنٹ کو جائزے کی اجازت نہیں ہے۔', failed: 'سائن اِن نہیں ہو سکا۔ آپ کے نوٹس اب بھی اس آلے پر محفوظ ہیں۔', loading: 'اکاؤنٹ کی تصدیق جاری ہے…', offline: 'نوٹس اس آلے پر محفوظ ہیں۔ سائن اِن کے لیے انٹرنیٹ درکار ہے۔', saving: 'محفوظ کیا جا رہا ہے…', saved: 'ویب سائٹ پر محفوظ ہو گیا', retry: 'محفوظ نہیں ہو سکا — نوٹس محفوظ ہیں اور دوبارہ بھیجے جائیں گے۔', legacy: 'پرانے نوٹس دوسرے نام سے محفوظ ہیں اور اس اکاؤنٹ کے نام سے اپ لوڈ نہیں ہوں گے۔', exportLegacy: 'پرانے نوٹس برآمد کریں', language: 'زبان' },
  };
  const languages = { ar: 'العربية', en: 'English', fr: 'Français', es: 'Español', pt: 'Português', ru: 'Русский', ur: 'اردو' };

  class ReviewError extends Error {
    constructor(kind, status = 0, retryMs = 0) {
      super(kind); this.kind = kind; this.status = status; this.retryMs = retryMs;
    }
  }
  function identity(value) {
    if (!value || typeof value.sub !== 'string' || !value.sub.length || value.sub.length > 255 ||
        typeof value.reviewer !== 'string' || !value.reviewer.length || value.reviewer.length > 60 ||
        !['reviewer', 'admin'].includes(value.role)) throw new ReviewError('failed');
    return { sub: value.sub, reviewer: value.reviewer, role: value.role };
  }
  function readNotes(storage, key) {
    const raw = storage.getItem(key);
    if (!raw) return {};
    const value = JSON.parse(raw);
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new ReviewError('failed');
    return value;
  }
  function create(options) {
    const { api, clientId, storage, onChange = () => {}, onRequired = () => {} } = options;
    const transport = options.fetch || root.fetch.bind(root);
    const base = new URL(api);
    let credential = null;
    let authorizationAttempt = 0;
    let profile = null;
    try { const raw = storage.getItem('review_profile_v1'); if (raw) profile = identity(JSON.parse(raw)); } catch { /* Retain original storage untouched. */ }
    let locale = 'ar';
    try { locale = storage.getItem('review_locale_v1') || locale; } catch {}
    if (!messages[locale]) locale = 'ar';
    const keyFor = (who) => who ? 'review_account_v1:' + who.sub : 'review';
    let notes = readNotes(storage, keyFor(profile));

    function failure(response) {
      const seconds = Number(response.headers.get('retry-after'));
      const retryMs = Number.isFinite(seconds) && seconds > 0 ? Math.min(seconds, 3600) * 1000 : 8000;
      return new ReviewError(response.status === 401 ? 'signIn' : response.status === 403 ? 'denied' : 'retry', response.status, retryMs);
    }
    async function authorize(token) {
      const attempt = ++authorizationAttempt;
      credential = null;
      const response = await transport(api + '/me', { headers: { Authorization: 'Bearer ' + token } });
      if (!response.ok) throw failure(response);
      const next = identity(await response.json());
      if (attempt !== authorizationAttempt) throw new ReviewError('failed');
      const nextKey = keyFor(next);
      let nextNotes;
      if (storage.getItem(nextKey) !== null) nextNotes = readNotes(storage, nextKey);
      else if (storage.getItem('reviewer') === next.reviewer) nextNotes = readNotes(storage, 'review');
      else nextNotes = {};
      // Preserve the original review/reviewer keys as an exportable backup.
      // Persist new scope before switching, and never persist a bearer token.
      storage.setItem(nextKey, JSON.stringify(nextNotes));
      storage.setItem('review_profile_v1', JSON.stringify(next));
      profile = next; notes = nextNotes; credential = token;
      onChange({ ...profile }, notes);
      return { ...profile };
    }
    async function request(url, init = {}) {
      if (!credential) throw new ReviewError('signIn', 401);
      const target = new URL(url);
      if (target.origin !== base.origin || (target.pathname !== base.pathname &&
          !target.pathname.startsWith(base.pathname + '/'))) throw new ReviewError('failed');
      const headers = new Headers(init.headers);
      const requestCredential = credential;
      headers.set('Authorization', 'Bearer ' + requestCredential);
      const response = await transport(url, { ...init, headers });
      if (!response.ok) {
        if ((response.status === 401 || response.status === 403) && credential === requestCredential) {
          credential = null; onRequired();
        }
        throw failure(response);
      }
      return response;
    }
    const session = {
      clientId, messages, languages, authorize, request,
      get profile() { return profile ? { ...profile } : null; },
      get notes() { return notes; },
      get signedIn() { return credential !== null; },
      get locale() { return locale; },
      text(key) { return messages[locale][key]; },
      setLocale(value) { if (messages[value]) { locale = value; storage.setItem('review_locale_v1', value); } },
      save(value) { storage.setItem(keyFor(profile), JSON.stringify(value)); notes = value; },
      signOut() { authorizationAttempt++; credential = null; onRequired(); },
      legacyExport() { return storage.getItem('review') || '{}'; },
      hasDifferentLegacy() {
        const name = storage.getItem('reviewer');
        return !!profile && name !== profile.reviewer && Object.keys(readNotes(storage, 'review')).length > 0;
      },
    };
    return session;
  }
  root.RafeeqReviewAuth = { create, messages, languages, ReviewError };
})(globalThis);
