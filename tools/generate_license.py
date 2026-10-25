#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 أداة توليد أكواد ترخيص برنامج Smart Clinic لإدارة العيادات الطبية — Loraneem Tech
================================================================================
 المدد المعتمدة حصراً:
 1. شهرية (1M - 30 يوماً)
 2. ثلاث أشهر (3M - 90 يوماً)
 3. ستة أشهر (6M - 180 يوماً)
 4. تسعة أشهر (9M - 270 يوماً)
 5. سنة (1Y - 365 يوماً)
 6. سنتان (2Y - 730 يوماً)
================================================================================
"""

import argparse
import hashlib
import os
import random
import re
import string
import sys
from datetime import datetime, timedelta

SALT = 'LORANEEM-TECH-CLINIC-2026'

DURATIONS = {
    '1M': {'label': 'شهرية', 'days': 30, 'desc': 'شهر واحد (30 يوماً)'},
    '3M': {'label': 'ثلاثة أشهر', 'days': 90, 'desc': '3 أشهر (90 يوماً)'},
    '6M': {'label': 'ستة أشهر', 'days': 180, 'desc': '6 أشهر (180 يوماً)'},
    '9M': {'label': 'تسعة أشهر', 'days': 270, 'desc': '9 أشهر (270 يوماً)'},
    '1Y': {'label': 'سنة', 'days': 365, 'desc': 'سنة كاملة (365 يوماً)'},
    '2Y': {'label': 'سنتان', 'days': 730, 'desc': 'سنتان كاملتان (730 يوماً)'},
    'LT': {'label': 'دائم', 'days': 36500, 'desc': 'ترخيص دائم مدى الحياة'},
}

def clean_device_id(raw_id: str) -> str:
    cleaned = re.sub(r'[^A-Za-z0-9]', '', raw_id or '').upper()
    return cleaned

def random_token(length: int = 4) -> str:
    alphabet = string.ascii_uppercase + string.digits
    return ''.join(random.choice(alphabet) for _ in range(length))

def generate_license_code(device_id: str, duration_code: str, token: str = None) -> dict:
    dev = clean_device_id(device_id)
    dur = duration_code.upper()
    if dur not in DURATIONS:
        raise ValueError(f"مدة غير صحيحة: {duration_code}. الخيارات المتاحة: {list(DURATIONS.keys())}")
    if len(dev) < 8:
        raise ValueError(f"رمز الجهاز قصير جداً: {device_id} (يجب أن يكون 12 حرفاً على الأقل)")
    
    if not token:
        token = random_token(4)
    else:
        token = re.sub(r'[^A-Za-z0-9]', '', token).upper()[:4].ljust(4, '0')
        
    payload = f"{dev}:{dur}:{token}:{SALT}"
    digest = hashlib.sha256(payload.encode('utf-8')).hexdigest().upper()
    sig = digest[:12]
    
    formatted_code = f"DA-{dur}-{token}-{sig[:4]}-{sig[4:8]}-{sig[8:12]}"
    raw_code = f"DA{dur}{token}{sig}"
    
    return {
        'formatted_code': formatted_code,
        'raw_code': raw_code,
        'device_id': dev,
        'duration_code': dur,
        'duration_label': DURATIONS[dur]['label'],
        'duration_desc': DURATIONS[dur]['desc'],
        'days': DURATIONS[dur]['days'],
        'token': token,
        'generated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'est_expiry': (datetime.now() + timedelta(days=DURATIONS[dur]['days'])).strftime('%Y-%m-%d')
    }

def generate_unlock_code(device_id: str, token: str = None) -> dict:
    dev = clean_device_id(device_id)
    if len(dev) < 8:
        raise ValueError(f"رمز الجهاز قصير جداً: {device_id}")
    
    if not token:
        token = 'UN' + random_token(2)
    else:
        token = re.sub(r'[^A-Za-z0-9]', '', token).upper()[:4].ljust(4, '0')
        
    payload = f"{dev}:UNLOCK:{token}:{SALT}"
    digest = hashlib.sha256(payload.encode('utf-8')).hexdigest().upper()
    sig = digest[:12]
    
    formatted_code = f"DA-UNLOCK-{token}-{sig[:4]}-{sig[4:8]}-{sig[8:12]}"
    return {
        'unlock_code': formatted_code,
        'device_id': dev,
        'token': token,
        'generated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    }

def verify_code(code: str, device_id: str) -> dict:
    dev = clean_device_id(device_id)
    clean = re.sub(r'[^A-Za-z0-9]', '', code).upper()
    
    if clean.startswith('DAUNLOCK'):
        if len(clean) != 24:
            return {'valid': False, 'message': 'طول كود فك القفل غير صحيح'}
        token = clean[8:12]
        sig = clean[12:24]
        expected_payload = f"{dev}:UNLOCK:{token}:{SALT}"
        expected_sig = hashlib.sha256(expected_payload.encode('utf-8')).hexdigest().upper()[:12]
        if sig == expected_sig:
            return {'valid': True, 'type': 'unlock', 'token': token}
        return {'valid': False, 'message': 'التوقيع الرقمي لكود فك القفل لا يطابق هذا الجهاز'}
        
    if not clean.startswith('DA') or len(clean) != 20:
        return {'valid': False, 'message': 'طول كود التفعيل أو البادئة غير صحيحة'}
        
    dur = clean[2:4]
    if dur not in DURATIONS:
        return {'valid': False, 'message': f'رمز المدة {dur} غير معروف'}
        
    token = clean[4:8]
    sig = clean[8:20]
    expected_payload = f"{dev}:{dur}:{token}:{SALT}"
    expected_sig = hashlib.sha256(expected_payload.encode('utf-8')).hexdigest().upper()[:12]
    
    if sig != expected_sig:
        return {'valid': False, 'message': 'كود التفعيل لا يطابق هذا الجهاز أو غير صحيح'}
        
    return {
        'valid': True,
        'type': 'activation',
        'duration_code': dur,
        'duration_label': DURATIONS[dur]['label'],
        'duration_desc': DURATIONS[dur]['desc'],
        'token': token
    }

def format_whatsapp_message(info: dict, clinic_name: str = '') -> str:
    name_str = f"عيادة / د. {clinic_name}\n" if clinic_name else ""
    return f"""مرحباً بكم،
{name_str}تم إصدار كود تفعيل برنامج Smart Clinic لإدارة العيادات الطبية لجهازكم:

• رمز الجهاز: {info['device_id']}
• مدة الترخيص: {info['duration_label']} ({info['duration_desc']})
• كود التفعيل: {info['formatted_code']}

طريقة التفعيل:
1. افتح برنامج Smart Clinic على جهاز العيادة.
2. الصق الكود أعلاه في خانة كود التفعيل.
3. اضغط «تفعيل الترخيص بالمدة المرخصة».

مع تحيات فريق التطوير — Loraneem Tech
هاتف / واتساب: +963-933713023
بريد: loraneemtech@gmail.com"""

def interactive_mode():
    print("=" * 65)
    print("  أداة توليد أكواد برنامج Smart Clinic لإدارة العيادات الطبية")
    print("  Loraneem Tech — نظام التراخيص المحدد المدة")
    print("=" * 65)
    
    while True:
        dev_id = input("\nأدخل رمز الجهاز (12 حرفاً كما يظهر في البرنامج): ").strip()
        cleaned_dev = clean_device_id(dev_id)
        if len(cleaned_dev) >= 8:
            break
        print("خطأ: رمز الجهاز يجب أن يكون 12 حرفاً. أعد المحاولة.")
        
    clinic_name = input("اسم العيادة أو الطبيب (اختياري، للرسالة): ").strip()
    
    print("\nاختر مدة الترخيص المطلوبة حصراً:")
    print("  1) شهرية (1M - 30 يوماً)")
    print("  2) ثلاث أشهر (3M - 90 يوماً)")
    print("  3) ستة أشهر (6M - 180 يوماً)")
    print("  4) تسعة أشهر (9M - 270 يوماً)")
    print("  5) سنة (1Y - 365 يوماً)")
    print("  6) سنتان (2Y - 730 يوماً)")
    print("  7) توليد كود فك القفل (Unlock Code) للمحاولات الفاشلة")
    
    choice = input("\nرقم الخيار [1-7]: ").strip()
    mapping = {
        '1': '1M',
        '2': '3M',
        '3': '6M',
        '4': '9M',
        '5': '1Y',
        '6': '2Y'
    }
    
    if choice == '7':
        unlock_info = generate_unlock_code(cleaned_dev)
        print("\n" + "=" * 65)
        print("  كود فك القفل (إلغاء قفل مربع الإدخال بعد محاولتين):")
        print(f"  {unlock_info['unlock_code']}")
        print("=" * 65)
        print(f"الجهاز: {cleaned_dev} | وقت التوليد: {unlock_info['generated_at']}")
        return
        
    if choice not in mapping:
        print("خيار غير صحيح!")
        return
        
    dur_code = mapping[choice]
    info = generate_license_code(cleaned_dev, dur_code)
    
    print("\n" + "=" * 65)
    print("  تم توليد كود الترخيص بنجاح:")
    print("=" * 65)
    print(f"  كود التفعيل:   {info['formatted_code']}")
    print(f"  رمز الجهاز:    {info['device_id']}")
    print(f"  المدة:         {info['duration_label']} ({info['duration_desc']})")
    print(f"  تاريخ التوليد: {info['generated_at']}")
    print(f"  الانتهاء التقريبي: {info['est_expiry']}")
    print("=" * 65)
    
    print("\n--- نص الرسالة الجاهزة للإرسال إلى العميل (واتساب / إيميل) ---")
    print(format_whatsapp_message(info, clinic_name))
    print("-" * 65)

def main():
    parser = argparse.ArgumentParser(description="أداة توليد أكواد ترخيص Smart Clinic")
    parser.add_argument('-d', '--device', help="رمز الجهاز (12 حرفاً)")
    parser.add_argument('-p', '--duration', choices=['1m', '3m', '6m', '9m', '1y', '2y', 'lt', 'LT', '1M', '3M', '6M', '9M', '1Y', '2Y'], help="مدة الترخيص")
    parser.add_argument('-c', '--clinic', default='', help="اسم المنشأة أو العيادة")
    parser.add_argument('-u', '--unlock', action='store_true', help="توليد كود فك القفل")
    parser.add_argument('-v', '--verify', help="التحقق من صحة كود تفعيل")
    
    args = parser.parse_args()
    
    if not any([args.device, args.duration, args.unlock, args.verify]):
        interactive_mode()
        return
        
    if args.verify:
        if not args.device:
            print("خطأ: يرجى تمرير رمز الجهاز عبر -d للتحقق من الكود.")
            sys.exit(1)
        res = verify_code(args.verify, args.device)
        print(res)
        return
        
    if not args.device:
        print("خطأ: يرجى تمرير رمز الجهاز عبر -d.")
        sys.exit(1)
        
    if args.unlock:
        res = generate_unlock_code(args.device)
        print(res['unlock_code'])
        return
        
    if not args.duration:
        print("خطأ: يرجى اختيار مدة الترخيص عبر -p (1m, 3m, 6m, 9m, 1y, 2y).")
        sys.exit(1)
        
    info = generate_license_code(args.device, args.duration.upper())
    print(info['formatted_code'])

if __name__ == '__main__':
    main()
